use strict;
use warnings;
use WbpsExpression::Analysis::DataFiles;
use Test::More;

sub test_average_and_aggregate {
  my ($name_to_pathlist_pairs, $frontmatter, $expected, $test_name) = @_;

  my $output = "";
  WbpsExpression::Analysis::DataFiles::average_and_aggregate($name_to_pathlist_pairs, \$output, @{$frontmatter});
  is($output, $expected, $test_name); 
}

test_average_and_aggregate([], [], "", "null case"); 
test_average_and_aggregate([], ["frontmatter", "lines"], "# frontmatter\n# lines\n", "frontmatter"); 

test_average_and_aggregate([
    ["adult female", []]
  ], [], "gene_id\tadult female\n", "one header no files");

test_average_and_aggregate([
    ["adult female", []]
  ], ["frontmatter"], "# frontmatter\ngene_id\tadult female\n", "one header no files - with frontmatter");

test_average_and_aggregate([
    ["adult female", []], ["adult male", []]
  ], [], "gene_id\tadult female\tadult male\n", "two headers no files");

my $gene = "first gene";
my $second_gene = "second gene";

my $h = "gene_id\t \n";
my $l1 = "$gene\t1.0\n";
my $l2 = "$gene\t2.0\n";
my $avg = "$gene\t1.5\n";
my $run_1 = "$h$l1";
my $run_2 = "$h$l2";

test_average_and_aggregate([
    ["adult female", [[\$run_1]]]
  ], [], "gene_id\tadult female\n$l1", "one header one file");

test_average_and_aggregate([
    ["adult female", [[\$run_1, \$run_2]]]
  ], [], "gene_id\tadult female\n$avg", "one header two files, avg as tech reps");

test_average_and_aggregate([
    ["adult female", [[\$run_1],[ \$run_2]]]
  ], [], "gene_id\tadult female\n$avg", "one header two files, avg as bio reps");

test_average_and_aggregate([
    ["adult female", [[\$run_1, \$run_1, \$run_1, \$run_2]]]
  ], [], "gene_id\tadult female\n$l1", "average is median");

test_average_and_aggregate([
    ["adult female", [[\$run_1, \$run_1, \$run_1, \$run_2], [ \$run_2]]]
  ], [], "gene_id\tadult female\n$avg", "average is median 2");

my $l3 = "$second_gene\t3.0\n";
my $run_3 = "$h$l3";
test_average_and_aggregate([
   ["adult female", [[\$run_1, \$run_3]]]
  ], [], "gene_id\tadult female\n$l1$l3", "two lines");

test_average_and_aggregate([
   ["adult female", [[\$run_1]]] , ["adult male", [[\$run_2]]]
  ], [], "gene_id\tadult female\tadult male\n$gene\t1.0\t2.0\n", "two headers");

done_testing;
