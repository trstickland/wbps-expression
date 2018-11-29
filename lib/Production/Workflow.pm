use strict;
use warnings;
package Production::Workflow;
use Production::Sheets;
use Production::CurationDefaults;
use Production::Analysis;
use PublicResources::Rnaseq;
use File::Basename qw/dirname/;
use File::Slurp qw/read_dir/;
use File::Path qw/make_path/;
use List::Util qw/first/;
use List::MoreUtils qw/uniq/;
use Model::Study;
sub new {
  my ($class, $root_dir, $src_dir, $work_dir) = @_;
  my $sheets = Production::Sheets->new($src_dir);
  return bless {
     processing_path => "$root_dir/curation",
     sheets => $sheets,
     public_rnaseq_studies => PublicResources::Rnaseq->new($root_dir, $sheets),
     analysis => Production::Analysis->new($work_dir),
  }, $class;
}
sub get_studies_in_sheets {
  my ($self, $species) = @_;
  return map {Model::Study->from_folder($_)} $self->{sheets}->dir_content_paths("studies", $species);
}

sub should_reject_study {
  my ($self, $study) = @_;
  return ($study->{design}->all_conditions < 2 || $study->{design}->all_runs < 6);
}

sub fetch_incoming_studies {
  my ($self, $public_study_records, $current_studies, $current_ignore_studies) = @_;

  my %result = (REJECT => [], SAVE => []); 

  for my $study ( map {&Production::CurationDefaults::study(%$_)} @{$public_study_records}){
    my $current_record = $current_studies->{$study->{study_id}};
    if ($current_ignore_studies->{$study->{study_id}} or $self->should_reject_study($study)){
      push @{$result{REJECT}}, $study;
    } else { 
      if ($current_record and Model::Study::config_matches_design_checks($current_record->{config}, $study->{design})){
        $study->{config}{slices} = $current_record->{config}{slices};
        $study->{config}{condition_names} = $current_record->{config}{condition_names};
        # Additionally, characteristics in the current record were already reused
        # because they provided sources of attributes for the runs - see PublicResources::Rnaseq
      }
      push @{$result{SAVE}}, $study;
    }
  };
  return \%result;
}
sub run_checks {
  my ($self, @studies) = @_;
  my %result = (FAILED_CHECKS => [], PASSED_CHECKS => []);
  for my $study (@studies){
    push @{$result{$study->passes_checks ? "PASSED_CHECKS" : "FAILED_CHECKS"}},$study;
  }
  return \%result;
}
sub do_everything {
  my ($self, $species, $assembly) = @_;
  my @public_study_records = $self->{public_rnaseq_studies}->get($species, $assembly);  
  my %current_studies = map {$_->{study_id}=> $_} $self->get_studies_in_sheets($species);
  my %current_ignore_studies = map {$_=>1} $self->{sheets}->list("ignore_studies", $species);
  my $incoming_studies = $self->fetch_incoming_studies(\@public_study_records, \%current_studies, \%current_ignore_studies);
  for my $study (@{$incoming_studies->{SAVE}}){
     $study->to_folder($self->{sheets}->path("studies", $species, $study->{study_id}));
  }
  if (@{$incoming_studies->{REJECT}}){
    $self->{sheets}->write_list( [uniq sort(keys %current_ignore_studies, map {$_->{study_id}} @{$incoming_studies->{REJECT}})], "ignore_studies", $species)
  }
  
  my $todo_studies = $self->run_checks(values %current_studies, @{$incoming_studies->{SAVE}});

  my %analysed_studies;
  for my $study (@{$todo_studies->{PASSED_CHECKS}}){
     my $public_study_record = first {$_->{study_id} eq $study->{study_id}} @public_study_records; 
     my %files = map {
        $_->{run_id} => { 
          %{$_->{data_files}},
          qc_issues => $_->{qc_issues},
        }} @{$public_study_record->{runs}};
     my $done = $self->{analysis}->run($study, \%files);
     push @{$analysed_studies{$done ? "DONE": "SKIPPED"}}, $study;
  }
  my %report = (%$incoming_studies, %$todo_studies, %analysed_studies);
  use YAML;
  print Dump(\%report);
  # Remaining:
  # - Deployment directory - link between production directory results, a corner of FTP where they serve, and where the paths should go
  # - Go through done / pending curation / rejected studies, and make a HTML page
  # - Internal report on what happened:
  #   + statuses: ignored / removed / unchanged / updated / failed_data_quality / failed_analysis 
  #   + more granular than html, which should only have successful and other
}
1;
