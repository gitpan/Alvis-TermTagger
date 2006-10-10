package Alvis::TermTagger;

our $VERSION = '0.1';

#######################################################################
#
# Last Update: 24/07/2006 (mm/dd/yyyy date format)
# 
# Copyright (C) 2006 Thierry Hamon
#
# Written by thierry.hamon@lipn.univ-paris13.fr
#
# Author : Thierry Hamon
# Email : thierry.hamon@lipn.univ-paris13.fr
# URL : http://www-lipn.univ-paris13.fr/~hamon
#
########################################################################

=head1 NAME

Alvis::TermTagger - Perl extension for tagging terms in a corpus

=head1 SYNOPSIS

use Alvis::TermTagger;

Alvis::TermTagger::termtagging($termlist, $outputfile);

=head1 DESCRIPTION

This module is used to tag a corpus with terms. Corpus (given on the
STDIN) is a file with one sentence per line. Term list (C<$termlist>)
is a file containing one term per line. For each term, additional
information can be given after a column. Each line of the output file
(C<$outputfile>) contains the sentence number and the term separated
by a tabulation character.

This module is mainly used in the Alvis NLP Platform.

=head1 METHODS

=cut

use strict;

# TODO : write functions for term tagginga, term selection with and
# without offset in the corpus


=head2 termtagging()

    termtagging($term_list_filename, $output_filename);

This is the main method of module. It loads the term list
(C<$term_list_filename>) and tags the corpus (C<$corpus_filename>). It
produces the list of matching terms and the sentence offset where the
terms can be found. The file C<$output_filename> contains this output.

=cut

sub termtagging {

    my ($corpus_filename, $term_list_filename, $output_filename) = @_;

    my @term_list;
    my @regex_term_list;
    my %corpus;
    my %lc_corpus;
    my %corpus_index;
    my %idtrm_select;

    &load_TermList($term_list_filename,\@term_list);
    &get_Regex_TermList(\@term_list, \@regex_term_list);
    &load_Corpus($corpus_filename,\%corpus, \%lc_corpus);
    &corpus_Indexing(\%lc_corpus, \%corpus_index);
    &term_Selection(\%corpus_index, \@term_list, \%idtrm_select);
    &term_tagging_offset(\@term_list, \@regex_term_list, \%idtrm_select, \%corpus, $output_filename);

    return(0);
}

=head2 load_TermList()

    load_TermList($term_list_filename,\@term_list);

This method loads the term list (C<$term_list_filename> is the file name) in the
array given by reference (C<\@term_list>).

=cut

sub load_TermList {
    my ($termlist_name, $ref_termlist) = @_;

    my $line;
    my $term;        # not use yet 
    my $suppl_info;  # not use yet 
    my @tab;

    warn "Loading the terminological resource\n";

    open DESC_TERMLIST, $termlist_name or die "$0: $termlist_name: No such file\n";

    binmode(DESC_TERMLIST, ":utf8");

    while($line = <DESC_TERMLIST>) {
	chomp $line;
	utf8::decode($line);
	
	# Blank and comment lines are throw away
	if (($line !~ /^\s*\#/)&&($line !~ /^\s*\/\//)&&($line !~ /^\s*$/)) {
	    # Term is split from the other information
	    # TODO : keep the additional information to restore them at the tagging
	    @tab = split / ?[\|:] ?/, $line;
	     if ($tab[0] !~ /^\s$/) {
		 $tab[0] =~ s/ +/ /g;
		 $tab[0] =~ s/ $//g;
		 $tab[0] =~ s/^ //g;
		 push @$ref_termlist, $tab[0];
	     }
 	 }
    }
    close DESC_TERMLIST;
    print STDERR "\n\tTerm list size : " . scalar(@$ref_termlist) . "\n\n";
}


=head2 get_Regex_TermList()

    get_Regex_TermList(\@term_list, \@regex_term_list);

This method generates the regular expression from the term list
(C<\@term_list>). stored in the specific array
(C<\@regex_term_list>)

=cut

sub get_Regex_TermList {

    my ($ref_termlist, $ref_regex_termlist) = @_;
    my $term_counter;

    warn "Generating the regular expression from the terms\n";

    for($term_counter  = 0;$term_counter < scalar @$ref_termlist;$term_counter++) {
	$ref_regex_termlist->[$term_counter] = $ref_termlist->[$term_counter];
	$ref_regex_termlist->[$term_counter] =~ s/([()\',\[\]\?\!:;\/.\+\-])/ \\$1 /g;
    }
    print STDERR "\n\tTerm/regex list size : " . scalar(@$ref_regex_termlist) . "\n\n";
}

=head2 load_Corpus()

    load_Corpus($corpus_filename\%corpus, \%lc_corpus);

This method loads the corpus (C<$corpus_filename>) in hashtable
(C<\%corpus>) and prepares the corpus in lower case (recorded in a
specific hashtable, C<\%lc_corpus>)

=cut

sub load_Corpus {

    my ($corpus_filename,$ref_tabh_Corpus, $ref_tabh_Corpus_lc) = @_;
    my $line;
    my $sent_id = 1;

    warn "Loading the corpus\n";

    # TODO read the corpus from a file

    open CORPUS, $corpus_filename or die "File $corpus_filename not found\n";
 
    binmode(CORPUS, ":utf8");
    
    while($line=<CORPUS>){
	chomp $line;
	$ref_tabh_Corpus->{$sent_id} = $line;
	$ref_tabh_Corpus_lc->{$sent_id} = lc $line;	
	$sent_id++;
    }
    close CORPUS;
    print STDERR "\n\tCorpus size : " . scalar(keys %$ref_tabh_Corpus) . "\n\n";
}

=head2 corpus_Indexing()

    corpus_Indexing(\%lc_corpus, \%corpus_index);

This method indexes the lower case version of the corpus
(C<\%lc_corpus>) according the words C<\%corpus_index> (the index is a
hashtable given by reference).

=cut


sub corpus_Indexing {
    my ($ref_corpus_lc, $ref_corpus_index) = @_;

    my $word;
    my @tab_words;
    my $sent_id;

    warn "Indexing the corpus\n";

    foreach $sent_id (keys %$ref_corpus_lc) {
	@tab_words = split /[ -]/, $ref_corpus_lc->{$sent_id};
	foreach $word (@tab_words) {
	    if (!exists $ref_corpus_index->{$word}) {
		my @tabtmp;
		$ref_corpus_index->{$word} = \@tabtmp;
	    }
	    push @{$ref_corpus_index->{$word}}, $sent_id;
	}
    }

    print STDERR "\n\tSize of the first selected term list: " . scalar(keys %$ref_corpus_index) . "\n\n";

}

=head2 term_Selection()

    term_Selection(\%corpus_index, \@term_list, \%idtrm_select);

This method selects the terms from the term list (C<\@term_list>)
potentially appearing in the corpus (that is the indexed corpus,
C<\%corpus_index>). Results are recorded in the hash table
C<\%idtrm_select>.

=cut

sub term_Selection {
    my ($ref_corpus_index, $ref_termlist, $ref_tabh_idtrm_select) = @_;
    my $counter;
    my $term;
    my @tab_termlex;
    my $i;
    my $word;
    my $sent_id;

    warn "Selecting the terms potentialy appearing in the corpus\n";

    my %tabh_numtrm_select;
    
    for($counter  = 0;$counter < scalar @$ref_termlist;$counter++) {
	$term = lc $ref_termlist->[$counter];
	@tab_termlex = split /[ -]+/, $term;
	$i=0; 
	do {
	    $word = $tab_termlex[$i];
	    if (($word ne "") && (exists $ref_corpus_index->{$word})) {
		if (!exists $ref_tabh_idtrm_select->{$counter}) {
		    my %tabhtmp2;
		    $ref_tabh_idtrm_select->{$counter} = \%tabhtmp2;
		}
		foreach $sent_id (@{$ref_corpus_index->{$word}}) {
		    ${$ref_tabh_idtrm_select->{$counter}}{$sent_id} = 1;
		}
	    }
	    $i++;
	} while((!exists $ref_corpus_index->{$word}) && ($i < scalar @tab_termlex));
    }

    warn "\nEnd of selecting the terms potentialy appearing in the corpus\n";

    print STDERR "\n\tSize of the selected term list: " . scalar(keys %$ref_tabh_idtrm_select) . "\n\n";

}

=head2 term_tagging_offset()

    term_tagging_offset(\@term_list, \@regex_term_list, \%idtrm_select, \%corpus, $output_filename);

This method tags the corpus C<\%corpus> with the terms (issued from
the term list C<\@term_list>, C<\@regex_term_list> is the term list
with regular expression), and selected in a previous step
(C<\%idtrm_select>). Resulting selected terms are recorded with their
offset in the file C<$output_filename>.

=cut

sub term_tagging_offset {
    my ($ref_termlist, $ref_regex_termlist, $ref_tabh_idtrm_select, $ref_tabh_corpus, $offset_tagged_corpus_name) = @_;
    my $counter;
    my $term_regex;
    my $idTrm;
    my $sent_id;
    my $line;

    warn "Term tagging\n";

    open TAGGEDCORPUS, ">$offset_tagged_corpus_name" or die "$0: $offset_tagged_corpus_name: No such file\n";

    binmode(TAGGEDCORPUS, ":utf8");

    foreach $counter (keys %$ref_tabh_idtrm_select) {
	$term_regex = $ref_regex_termlist->[$counter];
	$idTrm = $counter;
	foreach $sent_id (keys %{$ref_tabh_idtrm_select->{$counter}}){
	    $line = $ref_tabh_corpus->{$sent_id};
	    print STDERR ".";
	    
	    if ($line =~ / ($term_regex)[ ,]/i) {
		print TAGGEDCORPUS "$sent_id\t";
		print TAGGEDCORPUS $ref_termlist->[$counter];
		print TAGGEDCORPUS "\n";
	    }
	    if ($line =~ /^($term_regex) /i) {
		print TAGGEDCORPUS "$sent_id\t";
		print TAGGEDCORPUS $ref_termlist->[$counter];
		print TAGGEDCORPUS "\n";
	    }
	    if ($line =~ / ($term_regex)\.?$/i) {
		print TAGGEDCORPUS "$sent_id\t";
		print TAGGEDCORPUS $ref_termlist->[$counter];
		print TAGGEDCORPUS "\n";
	    }
	}
	print STDERR "\n";
    }

close TAGGEDCORPUS;

#########################################################################################################
    warn "\nEnd of term tagging\n";

}



=head1 SEE ALSO

Alvis web site: http://www.alvis.info

=head1 AUTHORS

Thierry Hamon <thierry.hamon@lipn.univ-paris13.fr>

=head1 LICENSE

Copyright (C) 2006 by Thierry Hamon

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.6 or,
at your option, any later version of Perl 5 you may have available.

=cut

1;
