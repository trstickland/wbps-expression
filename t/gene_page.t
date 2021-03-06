use strict;
use warnings;
use EnsEMBL::Web::Component::Gene::WBPSExpressionHelper;
use Test::More;
use File::Temp qw/tempdir/;
use File::Slurp qw/write_file/;
use File::Path qw/make_path/;

my $dir = tempdir(CLEANUP => 1);
my $file = <<EOF;
#temp file
gene_id	heads	tails
g1	1.1	1.2
EOF
my $study_id = "SRP071241";
my $category = "Organism parts";
my $study_title = "Comparison of gene expression between female Schistosoma mansoni heads and tails";
my $file_name = "$study_id.tpm.tsv";
my $file_path = join("/", $dir, $study_id, $file_name);

my $species = "schistosoma_mansoni_prjea36577";
my ($spe, $cies, $bp) = split "_", $species;
make_path(join("/", $dir, $study_id));
write_file($file_path, $file);

my $second_file = <<EOF;
# DESeq2 version: ‘1.22.1’
gene_id	5-AzaC vs untreated	
g2	1.1	0.04
EOF

my $second_study_id ="SRP130864";
my $second_category = "Response to treatment";
my $second_study_title = "5-AzaC effect on Schistosoma mansoni Transcriptome";
my $second_file_name = "$second_study_id.de.treatment.tsv";
my $second_file_path = join("/", $dir, $second_study_id, $second_file_name);
make_path(join("/", $dir, $second_study_id));
write_file($second_file_path, $second_file);

my $third_file = <<EOF;
gene_id	SRR5664530	SRR5664533	SRR5664534	SRR5664531	SRR5664532	SRR5664529	SRR5664535
g3	0.8	1.3	3.54	35.85	41.03	41.95	48.82
EOF

my $third_study_id ="SRP108901";
my $third_category = "Other";
my $third_study_title = "Schistosoma mansoni strain LE - Transcriptome or Gene expression";
my $third_file_name = "$third_study_id.tpm_per_run.tsv";
my $third_file_path = join("/", $dir, $third_study_id, $third_file_name);
make_path(join("/", $dir, $third_study_id));
write_file($third_file_path, $third_file);


my $fourth_file = <<EOF;
# Gene expression in TPM - technical, then biological replicates per condition for study ERP014584
gene_id	18 days post infection, single sex, female	18 days post infection, single sex, male	21 days post infection, mixed sex, female	21 days post infection, mixed sex, male	21 days post infection, single sex, female	21 days post infection, single sex, male	28 days post infection, mixed sex, female	28 days post infection, mixed sex, male	28 days post infection, single sex, female	28 days post infection, single sex, male	35 days post infection, mixed sex, female	35 days post infection, mixed sex, male	35 days post infection, single sex, female	35 days post infection, single sex, male	38 days post infection, mixed sex, female	38 days post infection, mixed sex, male	38 days post infection, single sex, female	38 days post infection, single sex, male
g4	57.5	76.6	88.2	92.8	91.6	79.0	71.1	74.1	75.4	67.9	44.0	55.7	56.1	49.3	24.7	61.9	56.6	49.2
EOF

my $fourth_study_id ="ERP014584";
my $fourth_category = "Life stages";
my $fourth_study_title = "Schistosoma mansoni RNASeq male and female characterisation";
my $fourth_file_name = "$fourth_study_id.tpm.tsv";
my $fourth_file_path = join("/", $dir, $fourth_study_id, $fourth_file_name);
make_path(join("/", $dir, $fourth_study_id));
write_file($fourth_file_path, $fourth_file);

my $studies_file = <<"EOF";
$study_id\t$category\t$study_title
$second_study_id\t$second_category\t$second_study_title
$third_study_id\t$third_category\t$third_study_title
$fourth_study_id\t$fourth_category\t$fourth_study_title
EOF

write_file(join("/", $dir, "$spe\_$cies.studies.tsv"), $studies_file);

my $subject = EnsEMBL::Web::Component::Gene::WBPSExpressionHelper->from_folder(
   $species, $dir
);
is( scalar @{$subject->{studies}}, 4, "Read in four studies");

sub is_empty_response {
  my ($payload, $test_name) = @_;
  subtest $test_name => sub {
     like($payload, qr{no results}i,  "no results");
  };
}
sub is_table {
  my ($payload,$num_rows, $num_cols, $num_cells, $test_name) = @_;
  subtest $test_name => sub {
    
    my @empty_td_tags = $payload =~ m{<td></td>}g;
    my @td_tags = $payload =~ m{<td>.+?</td>}g;
    my @th_rows = $payload =~ m{<th scope="row".*?>}g;
    my @th_cols = $payload =~ m{<th scope="col".*?>}g;
    ok( @empty_td_tags < 2, "at most one empty cell - top left"); 
    is (scalar @th_rows, $num_rows, "num rows");
    is (scalar @th_cols, $num_cols, "num cols");
    is (scalar @td_tags, $num_cells, "num cells");
  } or diag explain $payload;
}
sub has_study_title {
  my ($payload, $title, $test_name) = @_;
  $test_name //= $title;
  like ($payload, qr{<a .*$title.*</a>}, $test_name) or diag explain $payload;
}
is_empty_response($subject->render_page("g0", $_), "Invalid gene, category $_") for ($category, $second_category, $third_category, "invalid category");
is_empty_response($subject->render_page("g1", "invalid category"), "g1 invalid category");
is_table($subject->render_page("g1", $category),1,2, 2, "$category - one row in a flat table");
is_table($subject->render_page("g2", $second_category),0 ,4, 4, "$second_category ");
is_table($subject->render_page("g3", $third_category),1,6, 6, "$third_category - six stats");
is_table($subject->render_page("g4", $fourth_category), 4,5,20, "$fourth_category - two dimensional");
has_study_title($subject->render_page("g1", $category), $study_title);
has_study_title($subject->render_page("g2", $second_category), $second_study_title);
has_study_title($subject->render_page("g3", $third_category), $third_study_title);
has_study_title($subject->render_page("g4", $fourth_category), $fourth_study_title);

done_testing;
