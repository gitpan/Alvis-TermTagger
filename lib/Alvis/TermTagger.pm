package Alvis::TermTagger;

our $VERSION = '0.4';

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


use strict;

# TODO : write functions for term tagginga, term selection with and
# without offset in the corpus


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
                 my @tmptab = ($tab[0], $tab[1]);
		 push @$ref_termlist, \@tmptab;
	     }
 	 }
    }
    close DESC_TERMLIST;
    print STDERR "\n\tTerm list size : " . scalar(@$ref_termlist) . "\n\n";
}



sub get_Regex_TermList {

    my ($ref_termlist, $ref_regex_termlist) = @_;
    my $term_counter;

    warn "Generating the regular expression from the terms\n";

    for($term_counter  = 0;$term_counter < scalar @$ref_termlist;$term_counter++) {
	$ref_regex_termlist->[$term_counter] = $ref_termlist->[$term_counter]->[0];
	$ref_regex_termlist->[$term_counter] =~ s/([()\',\[\]\?\!:;\/.\+\-])/ \\$1 /g;
    }
    print STDERR "\n\tTerm/regex list size : " . scalar(@$ref_regex_termlist) . "\n\n";
}

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


sub corpus_Indexing {
    my ($ref_corpus_lc, $ref_corpus_index) = @_;

    my $word;
    my @tab_words;
    my $sent_id;

    warn "Indexing the corpus\n";

    foreach $sent_id (keys %$ref_corpus_lc) {
	@tab_words = split /[ -.,]/, $ref_corpus_lc->{$sent_id};
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
	$term = lc $ref_termlist->[$counter]->[0];
#         warn "Scanning term : $term\n";
	@tab_termlex = split /[ -]+/, $term;
#         warn "Split term : \n";
#         foreach $word (@tab_termlex) {
# 	    warn "\t$word\n";
# 	}
	$i=0; 
	do {
	    $word = $tab_termlex[$i];
	    if (($word ne "") && ((length($word) > 3) || (scalar(@tab_termlex)==1)) && (exists $ref_corpus_index->{$word})) {
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

#     print STDERR "\n\tSize of the selected term list: " . scalar(keys %$ref_tabh_idtrm_select) . "\n\n";
#     foreach my $counter (keys %$ref_tabh_idtrm_select) {
#         my $term_regex = $ref_termlist->[$counter];
# 	print STDERR $term_regex . "\n";
#     }

}


sub term_tagging_offset {
    my ($ref_termlist, $ref_regex_termlist, $ref_tabh_idtrm_select, $ref_tabh_corpus, $offset_tagged_corpus_name) = @_;
    my $counter;
    my $term_regex;
    my $sent_id;
    my $line;

    warn "Term tagging\n";

    open TAGGEDCORPUS, ">$offset_tagged_corpus_name" or die "$0: $offset_tagged_corpus_name: No such file\n";

    binmode(TAGGEDCORPUS, ":utf8");

    foreach $counter (keys %$ref_tabh_idtrm_select) {
	$term_regex = $ref_regex_termlist->[$counter];
	foreach $sent_id (keys %{$ref_tabh_idtrm_select->{$counter}}){
	    $line = $ref_tabh_corpus->{$sent_id};
	    print STDERR ".";
	    
	    if ($line =~ / ($term_regex)[,.?!:; ]/i) {
		printMatchingTerm(\*TAGGEDCORPUS, $ref_termlist->[$counter], $sent_id);
	    }
	    if ($line =~ /^($term_regex)[,.?!:; ]/i) {
		printMatchingTerm(\*TAGGEDCORPUS, $ref_termlist->[$counter], $sent_id);
	    }
	    if ($line =~ / ($term_regex)$/i) {
		printMatchingTerm(\*TAGGEDCORPUS, $ref_termlist->[$counter], $sent_id);
	    }
	}
	print STDERR "\n";
    }

close TAGGEDCORPUS;

#########################################################################################################
    warn "\nEnd of term tagging\n";

}

sub printMatchingTerm() {

    my ($descriptor, $ref_matching_term, $sent_id) = @_;

    print $descriptor "$sent_id\t";
    print $descriptor $ref_matching_term->[0];
    if (defined ($ref_matching_term->[1])) {
	print $descriptor "\t" . $ref_matching_term->[1];
    }
    print $descriptor "\n";

}


sub term_tagging_offset_tab {
    my ($ref_termlist, $ref_regex_termlist, $ref_tabh_idtrm_select, $ref_tabh_corpus, $ref_tab_results) = @_;
    my $counter;
    my $term_regex;
    my $sent_id;
    my $line;
    my $i;
    my $size_termselect = scalar(keys %$ref_tabh_idtrm_select);

#     warn "Term tagging\n";

    
    $i = 0;
    
    foreach $counter (keys %$ref_tabh_idtrm_select) {
	printf STDERR "Term tagging... %0.1f%%\r", ($i/$size_termselect)*100 ;
	$term_regex = $ref_regex_termlist->[$counter];
	foreach $sent_id (keys %{$ref_tabh_idtrm_select->{$counter}}){
	    $line = $ref_tabh_corpus->{$sent_id};
#	    print STDERR ".";
	    
	    if ($line =~ / ($term_regex)[,.?!:; ]/i) {
		printMatchingTerm_tab($ref_termlist->[$counter], $sent_id, $ref_tab_results);
	    }
	    if ($line =~ /^($term_regex)[,.?!:; ]/i) {
		printMatchingTerm_tab($ref_termlist->[$counter], $sent_id, $ref_tab_results);
	    }
	    if ($line =~ / ($term_regex)$/i) {
		printMatchingTerm_tab($ref_termlist->[$counter], $sent_id, $ref_tab_results);
	    }
	}
	$i++;
    }
    print STDERR "\n";

#########################################################################################################
    warn "\nEnd of term tagging\n";

}

sub printMatchingTerm_tab() {

    my ($ref_matching_term, $sent_id, $ref_tab_results) = @_;

    my $tmp_line = "";
    my $tmp_key;

    if (ref($ref_tab_results) eq "ARRAY") {
	$tmp_line .= "$sent_id\t";
	$tmp_line .= $ref_matching_term->[0];
	if (defined ($ref_matching_term->[1])) {
	    $tmp_line .= "\t" . $ref_matching_term->[1];
	}
	push @$ref_tab_results, $tmp_line;
    } else {
	if (ref($ref_tab_results) eq "HASH") {
	    my @tab_tmp;
	    $tmp_key .= $sent_id . "_";
	    $tmp_key .= $ref_matching_term->[0];
	    push @tab_tmp, $sent_id;
	    push @tab_tmp, $ref_matching_term->[0];
	    if (defined ($ref_matching_term->[1])) {
		push @tab_tmp, $ref_matching_term->[1];
	    }

	    $ref_tab_results->{$tmp_key} = \@tab_tmp;
	}
    }

}



1;

__END__

=head1 NAME

Alvis::TermTagger - Perl extension for tagging terms in a corpus

=head1 SYNOPSIS

use Alvis::TermTagger;

Alvis::TermTagger::termtagging($termlist, $outputfile);

=head1 DESCRIPTION

This module is used to tag a corpus with terms. Corpus (given on the
STDIN) is a file with one sentence per line. Term list (C<$termlist>)
is a file containing one term per line. For each term, additionnal
information (as canonical form) can be given after a column. Each line
of the output file (C<$outputfile>) contains the sentence number, the
term, additional information, all separated by a tabulation character.

This module is mainly used in the Alvis NLP Platform.

=head1 METHODS



=head2 termtagging()

    termtagging($term_list_filename, $output_filename);

This is the main method of module. It loads the term list
(C<$term_list_filename>) and tags the corpus (C<$corpus_filename>). It
produces the list of matching terms and the sentence offset (and
additional information given in the input file) where the terms can be
found. The file C<$output_filename> contains this output.


=head2 load_TermList()

    load_TermList($term_list_filename,\@term_list);

This method loads the term list (C<$term_list_filename> is the file
name) in the array given by reference (C<\@term_list>). Each element
of term list contains a reference to a two element array (the term and
its canonical form).


=head2 get_Regex_TermList()

    get_Regex_TermList(\@term_list, \@regex_term_list);

This method generates the regular expression from the term list
(C<\@term_list>). stored in the specific array
(C<\@regex_term_list>)


=head2 load_Corpus()

    load_Corpus($corpus_filename\%corpus, \%lc_corpus);

This method loads the corpus (C<$corpus_filename>) in hashtable
(C<\%corpus>) and prepares the corpus in lower case (recorded in a
specific hashtable, C<\%lc_corpus>)



=head2 corpus_Indexing()

    corpus_Indexing(\%lc_corpus, \%corpus_index);

This method indexes the lower case version of the corpus
(C<\%lc_corpus>) according the words C<\%corpus_index> (the index is a
hashtable given by reference).



=head2 term_Selection()

    term_Selection(\%corpus_index, \@term_list, \%idtrm_select);

This method selects the terms from the term list (C<\@term_list>)
potentially appearing in the corpus (that is the indexed corpus,
C<\%corpus_index>). Results are recorded in the hash table
C<\%idtrm_select>.


=head2 term_tagging_offset()

    term_tagging_offset(\@term_list, \@regex_term_list, \%idtrm_select, \%corpus, $output_filename);

This method tags the corpus C<\%corpus> with the terms (issued from
the term list C<\@term_list>, C<\@regex_term_list> is the term list
with regular expression), and selected in a previous step
(C<\%idtrm_select>). Resulting selected terms are recorded with their
offset, and additional information in the file C<$output_filename>.


=head2 term_tagging_offset_tab()

    term_tagging_offset(\@term_list, \@regex_term_list, \%idtrm_select, \%corpus, \@tab_results);

or 

    term_tagging_offset(\@term_list, \@regex_term_list, \%idtrm_select, \%corpus, \%tabh_results);

This method tags the corpus C<\%corpus> with the terms (issued from
the term list C<\@term_list>, C<\@regex_term_list> is the term list
with regular expression), and selected in a previous step
(C<\%idtrm_select>). Resulting selected terms are recorded with their
offset, and additional information in the array C<@tab_results>
(values are sentence id, selected terms and additional information
separated by tabulation) or in the hashtable C<%tabh_results> (keys
form is "sentenceid_selectedterm", values are an array reference
containing sentence id, selected terms and additional ifnormation).

=head2 printMatchingTerm

    printMatchingTerm($descriptor, $ref_matching_term, $sentence_id);

This method prints into the file descriptor C<$descriptor>, the
sentence id (C<$sentence_id>) and the matching term (named by its
reference C<$ref_matching_term>). Both data are on a line and are
separated by a tabulation character.

=head2 printMatchingTerm_tab

    printMatchingTerm_tab($ref_matching_term, $sentence_id, $ref_tab_results);

This method stores into C<$ref_tab_results>, the sentence id
(C<$sentence_id>) and the matching term (named by its reference
C<$ref_matching_term>). C<$ref_tab_results> can be a array or a hash
table. In case of an array, both data are concatanated in a line and
are separated by a tabulation character. In case of a hash table, both
data are stored in an array, hash key is the concatenation of the
sentence id and the matching term.


=head1 SEE ALSO

Alvis web site: http://www.alvis.info

=head1 AUTHORS

Thierry Hamon <thierry.hamon@lipn.univ-paris13.fr>

=head1 LICENSE

Copyright (C) 2006 by Thierry Hamon

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.6 or,
at your option, any later version of Perl 5 you may have available.


