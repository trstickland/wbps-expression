use strict;
use warnings;
use EnsEMBL::Web::Component::Gene::WbpsExpression;
use Test::More skip_all => "TODO";
use File::Temp qw/tempdir/;
use File::Slurp qw/write_file/;
use File::Path qw/make_path/;

my $dir = tempdir(CLEANUP => 1);
my $file = <<EOF;
#temp file
	heads	tails
g1	1.1	1.2
g2	2.1	2.2
EOF
my $study_id = "SRP071241";
my $category = "Organism parts";
my $study_title = "Comparison of gene expression between female Schistosoma mansoni heads and tails";
my $file_name = "$study_id.tpm.tsv";
my $file_path = join("/", $dir, $study_id, $file_name);

my $species = "schistosoma_mansoni";
my $assembly = "Smansoni_v7";
make_path(join("/", $dir, $study_id));
write_file($file_path, $file);

my $second_file = <<EOF;
# DESeq2 version: ‘1.22.1’
	5-AzaC vs untreated
g1	1.1
g3	-2.3
EOF

my $second_study_id ="SRP130864";
my $second_category = "Response to treatment";
my $second_study_title = "5-AzaC effect on Schistosoma mansoni Transcriptome";
my $second_file_name = "$second_study_id.de.treatment.tsv";
my $second_file_path = join("/", $dir, $study_id, $second_file_name);
make_path(join("/", $dir, $second_study_id));
write_file($second_file_path, $second_file);

my $third_file = <<EOF;
        SRR5664530      SRR5664533      SRR5664534      SRR5664531      SRR5664532      SRR5664529      SRR5664535
g1	0.8     1.3     3.54    35.85   41.03   41.95   48.82
g2      11.61   11.32   13.32   120.31  128.8   140.44  148.89
EOF

my $third_study_id ="SRP108901";
my $third_category = "Other";
my $third_study_title = "Schistosoma mansoni strain LE - Transcriptome or Gene expression";
my $third_file_name = "$third_study_id.tpm_per_run.tsv";
my $third_file_path = join("/", $dir, $study_id, $third_file_name);
make_path(join("/", $dir, $third_study_id));
write_file($third_file_path, $third_file);

my $studies_file = <<"EOF";
$study_id\t$category\t$study_title
$second_study_id\t$second_category\t$second_study_title
$third_study_id\t$third_category\t$third_study_title
EOF

write_file(join("/", $dir, "$species.$assembly.studies.tsv"), $studies_file);

my $subject = EnsEMBL::Web::Component::Gene::WbpsExpression::from_folder(
   $species, $assembly, $dir
);

is_deeply($subject, bless({
  studies => [{
     study_id => $study_id,
     study_title => $study_title,
     study_category => $category,
     tpms_per_condition => $file_path,
  }, {
     study_id => $second_study_id,
     study_title => $second_study_title,
     study_category => $second_category,
     contrasts => {
         treatment => $second_file_path
       }
  }, {
     study_id => $third_study_id,
     study_title => $third_study_title,
     study_category => $third_category,
     tpms_per_run => $third_file_name,
  } ]
}, 'EnsEMBL::Web::Component::Gene::WbpsExpression'), "Create reads in the config");

is_deeply($subject->tpms_in_tables("invalid ID", $category), [], "Null case - gene");
is_deeply($subject->tpms_in_tables("g1", "Different category"), [], "Null case - category");

is_deeply($subject->tpms_in_tables("g1", $category), [{
  study_id => $study_id,
  study_title => $study_title,
  column_headers => ["heads", "tails"],
  values => [1.1, 1.2],
}] , "One line - $category");


is_deeply([$subject->list_of_fold_changes_in_studies_and_studies_with_no_results("invalid ID", $second_category)], [[],[]], "Null case - no data anywhere");
is_deeply([$subject->list_of_fold_changes_in_studies_and_studies_with_no_results("g2", $second_category)], [[],[]], "Null case - gene, no data for the category");
is_deeply([$subject->list_of_fold_changes_in_studies_and_studies_with_no_results("g1", "Different category")], [[],[]], "Null case - category");

is_deeply([$subject->list_of_fold_changes_in_studies_and_studies_with_no_results("g1", $second_category)], [[{
  study_id => $second_study_id,
  study_title => $second_study_title,
  contrast => "5-AzaC vs untreated",
  fold_change => 1.1,
}],[]] , "One line - $second_category");


is_deeply($subject->summary_stats_in_tables("g1", $third_category), [{
  study_id => $third_study_id,
  study_title => $third_study_title,
  column_headers => ["N", "min", "Q1", "Q2", "Q3", "max"],
  values => [6,7,8,9,10],
}] , "One line - $third_category");
done_testing;
