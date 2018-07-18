
package GenomeBrowser::JBrowseDataFolder;
use strict;
use Carp;
use File::Path qw(make_path);
use File::Slurp qw(write_file);
use JSON;
use SpeciesFtp;
use GenomeBrowser::JBrowseTools;

# This is the data folder for jbrowse consumption
#
# input parameters: 
#  - where to construct the folder
#  - corresponding data production location


sub new {
  my ($class, $root_dir, $core_db) = @_;
  croak "Not enough args: @_" unless $root_dir and $core_db;

  my ($spe, $cies, $bioproject) = split "_", $core_db;
  my $species = join "_", $spe, $cies, $bioproject;
  my $dir = "$root_dir/$species";

  make_path $dir;

  return bless {
    species => $species,
    core_db => $core_db,
    dir => $dir,
  }, $class;
}


my $CONFIG_STANZA = {
   "include" => [
      "functions.conf"
   ],
   "names" => {
      "type" => "Hash",
      "url" => "names/"
   },
};

my $TRACK_STANZA = {
  storeClass => "JBrowse/Store/SeqFeature/BigWig",
  type => "JBrowse/View/Track/Wiggle/XYPlot",
  category => "RNASeq",
  autoscale => "local",
  ScalePosition => "right",
};


my $local_tracks = [
  {
    'feature' => 'WormBase,WormBase_imported',
    'trackLabel' => 'Gene Models',
    'trackType' => 'CanvasFeatures',
    'category' => 'Genome Annotation',
    'type' => [qw/gene mRNA exon CDS five_prime_UTR three_prime_UTR tRNA rRNA pseudogene tRNA_pseudogene antisense_RNA lincRNA miRNA miRNA_primary_transcript mRNA piRNA pre_miRNA pseudogenic_rRNA pseudogenic_transcript pseudogenic_tRNA scRNA snoRNA snRNA ncRNA/]
  },
  {
    'feature' => 'ncrnas_predicted',
    'trackLabel' => 'Predicted non-coding RNA (ncRNA)',
    'trackType' => 'FeatureTrack',
    'category' => 'Genome Annotation',
    'type' => ['nucleotide_match']
  },
  {
    'feature' => 'RepeatMasker',
    'trackLabel' => 'Repeat Region',
    'trackType' => 'FeatureTrack',
    'category' => 'Repeat Regions',
    'type' => ['repeat_region']
  },
  {
    'feature' => 'dust',
    'trackLabel' => 'Low Complexity Region (Dust)',
    'trackType' => 'FeatureTrack',
    'category' => 'Repeat Regions',
    'type' => ['low_complexity_region']
  },
  {
    'feature' => 'tandem',
    'trackLabel' => 'Tandem Repeat (TRFs)',
    'trackType' => 'FeatureTrack',
    'category' => 'Repeat Regions',
    'type' => ['tandem_repeat']
  }
];
sub make_all {
  my ($self, $jbrowse_install, $processing_dir) = @_;
  
  my $jbrowse_tools= GenomeBrowser::JBrowseTools->new(install_location => $jbrowse_install, tmp => $processing_dir, verbose => 1);
  my @track_configs;

  $jbrowse_tools->prepare_sequence(
    output_path => $self->{dir},
    input_path => SpeciesFtp->current_staging->path_to($self->{core_db}, "genomic.fa")
  ) unless -d $self->path_to("SEQUENCE");
  #push @track_configs, GenomeBrowser::TrackConfig::sequence_track();

  for my $local_track (@$local_tracks){
    my $f = $self->path_to("TRACK_FILES_LOCAL", $local_track->{track_label});
    $jbrowse_tools->track_from_annotation(
        %$local_track, 
        output_path => $f,
        input_path => SpeciesFtp->current_staging->path_to($self->{core_db}, "annotations.gff3")
    ) unless ( -f $f );

  }
  $jbrowse_tools->index_names(output_path => $self->{dir})
    unless -d $self->path_to("INDEXES");
  
  print "Copy includes TODO" 
    unless -d $self->path_to("INCLUDES"); 
 
  print "TODO read config in?"; 
  my %config = %$CONFIG_STANZA;
  #push @track_configs, $self->gene_models_track;
  #push @track_configs, $self->feature_tracks;

  my ($attribute_query_order, @rnaseq_tracks) = GenomeBrowser::RnaseqTracks("$processing_dir/rnaseq", $self->{core_db});
  
  for my $rnaseq_track (@rnaseq_tracks) {
     GenomeBrowser::Deployment::sync_ebi_to_sanger($rnaseq_track->{run_id});
     push @track_configs, $self->rnaseq_track_config($_);
  }
  
  
   $config{trackSelector} = {
     type => "Faceted",
     displayColumns => ["type", "category", @$attribute_query_order]
   } if @rnaseq_tracks;

  $config{tracks}=\@track_configs; 

  write_file($self->path_to("CONFIG").".1", \%config);
}

my $CONTENT_NAMES = {
  SEQUENCE => "seq",
  INDEXES => "names",
  TRACK_FILES_LOCAL => "tracks",
  CONFIG => "trackList.json",
  INCLUDES => "functions.conf",
};

sub path_to {
  my ($self, $name, @others) = @_;
  confess "No such JBrowse item: $name" unless $CONTENT_NAMES->{$name};
  return join "/", $self->{dir}, $CONTENT_NAMES->{$name}, @others; 
}
sub rnaseq_track_config {
  my ($self, %args) = @_;

  return {what => "rnaseq track placeholder", %args};
}
1;
