package Alvis::TermTagger;

our $VERSION = '0.8';

#######################################################################
#
# Last Update: 21/12/2010 (mm/dd/yyyy date format)
# 
# Copyright (C) 2006 Thierry Hamon
#
# Written by thierry.hamon@univ-paris13.fr
#
# Author : Thierry Hamon
# Email : thierry.hamon@univ-paris13.fr
# URL : http://www-limbio.smbh.univ-paris13.fr/membres/hamon/
#
########################################################################


use strict;
use warnings;

# TODO : write functions for term tagginga, term selection with and
# without offset in the corpus

sub termtagging {

    my ($corpus_filename, $term_list_filename, $output_filename, $lemmatised_corpus_filename, $caseSensitive) = @_;

    my @term_list;
    my %term_listIdx;
    my @regex_term_list;
    my @regex_lemmawordterm_list;
    my %corpus;
    my %lc_corpus;
    my %lemmatised_corpus;
    my %lc_lemmatised_corpus;
    my %corpus_index;
    my %lemmatised_corpus_index;
    my %idtrm_select;
    my %idlemtrm_select;

    if (!defined $caseSensitive) {
	$caseSensitive = -1;
    }

    &load_TermList($term_list_filename,\@term_list, \%term_listIdx);
    &get_Regex_TermList(\@term_list, \@regex_term_list, \@regex_lemmawordterm_list);

    &load_Corpus($corpus_filename, \%corpus, \%lc_corpus);
    if (defined $lemmatised_corpus_filename) {
	&load_Corpus($lemmatised_corpus_filename, \%lemmatised_corpus, \%lc_lemmatised_corpus);
    }
    &corpus_Indexing(\%lc_corpus, \%corpus, \%corpus_index, $caseSensitive);
    if (defined $lemmatised_corpus_filename) {
	&corpus_Indexing(\%lc_lemmatised_corpus, \%lemmatised_corpus, \%lemmatised_corpus_index, $caseSensitive);
    }
    &term_Selection(\%corpus_index, \@term_list, \%idtrm_select, $caseSensitive);
    if (defined $lemmatised_corpus_filename) {
	&term_Selection(\%lemmatised_corpus_index, \@term_list, \%idlemtrm_select, $caseSensitive);
    }
    &term_tagging_offset(\@term_list, \@regex_term_list, \%idtrm_select, \%corpus, $output_filename, $caseSensitive);
    if (defined $lemmatised_corpus_filename) {
	&term_tagging_offset(\@term_list, \@regex_lemmawordterm_list, \%idlemtrm_select, \%lemmatised_corpus, $output_filename, $caseSensitive);
    }
    return(0);
}


sub load_TermList {
    my ($termlist_name, $ref_termlist, $ref_termlistIdx) = @_;

    my $line;
    my $line1;
    my $term;        # not use yet 
    my $suppl_info;  # not use yet 
    my @tab;

    warn "Loading the terminological resource\n";

    open DESC_TERMLIST, $termlist_name or die "$0: $termlist_name: No such file\n";

    binmode(DESC_TERMLIST, ":utf8");

    while($line1 = <DESC_TERMLIST>) {
	chomp $line1;
	utf8::decode($line1);
	$line=$line1;

	# Blank and comment lines are throw away
	if (($line !~ /^\s*\#/o)&&($line !~ /^\s*\/\//o)&&($line !~ /^\s*$/o)) {
	    # Term is split from the other information
	    my @tab = split / ?[\|:] ?/, $line;
	     if ($tab[0] !~ /^\s*$/) {
		 # TODO better
		 $tab[0] =~ s/ +/ /go;
		 $tab[0] =~ s/ $//go;
		 $tab[0] =~ s/^ //go;
#		 $tab[0] =~ s/\\:/:/go;
		 if (!exists $ref_termlistIdx->{$tab[0]}) {
		     push @$ref_termlist, \@tab;
		     $ref_termlistIdx->{$tab[0]} = scalar(@$ref_termlist) -1;
		 } else {
		     $ref_termlist->[$ref_termlistIdx->{$tab[0]}]->[2] .= ";" . $tab[2];
		 }
	     }
 	 }
    }
    close DESC_TERMLIST;
    print STDERR "\n\tTerm list size : " . scalar(@$ref_termlist) . "\n\n";
}

sub get_Regex_TermList {

    my ($ref_termlist, $ref_regex_termlist, $ref_regex_lemmaWordtermlist) = @_;
    my $term_counter;

    warn "Generating the regular expression from the terms\n";

    for($term_counter  = 0;$term_counter < scalar @$ref_termlist;$term_counter++) {
	$ref_regex_termlist->[$term_counter] = $ref_termlist->[$term_counter]->[0];
	if (defined $ref_regex_lemmaWordtermlist) {
	    if (defined $ref_termlist->[$term_counter]->[3]) {
		$ref_regex_lemmaWordtermlist->[$term_counter] = $ref_termlist->[$term_counter]->[3];
	    } else {
		$ref_regex_lemmaWordtermlist->[$term_counter] = $ref_termlist->[$term_counter]->[0];
	    }
	}
#	warn $ref_regex_lemmaWordtermlist->[$term_counter] . "\n";
 	$ref_regex_termlist->[$term_counter] =~ s/([()\',\[\]\?\!:;\/.\+\-\*\#\{\}\\])/\\$1/og;
	$ref_regex_termlist->[$term_counter] =~ s/ /[\- \n]/og;
	if (defined $ref_regex_lemmaWordtermlist) {
	    $ref_regex_lemmaWordtermlist->[$term_counter] =~ s/([()\',\[\]\?\!:;\/.\+\-\*\#\{\}\\])/\\$1/og;
	    $ref_regex_lemmaWordtermlist->[$term_counter] =~ s/ /[\- \n]/og;
	}
    }
    print STDERR "\n\tTerm/regex list size : " . scalar(@$ref_regex_termlist);
    if (defined $ref_regex_lemmaWordtermlist) {
	print STDERR" / " . scalar(@$ref_regex_lemmaWordtermlist);
    }
    print STDERR "\n\n";
}

sub load_Corpus {

    my ($corpus_filename,$ref_tabh_Corpus, $ref_tabh_Corpus_lc) = @_;
    my $line;
    my $sent_id = 1;

    warn "Loading the corpus\n";

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
    my ($ref_corpus_lc, $ref_corpus, $ref_corpus_index, $caseSensitive) = @_;

    my $word;
    my @tab_words;
    my @tab_words_lc;
    my $sent_id;
    my $i;

    warn "Indexing the corpus\n";

    foreach $sent_id (keys %$ref_corpus_lc) { # \-\.,\n;\/
	@tab_words = split /[ ()\',\[\]\?\!:;\/\.\+\-\*\#\{\}\n]/, $ref_corpus->{$sent_id};
	@tab_words_lc = split /[ ()\',\[\]\?\!:;\/\.\+\-\*\#\{\}\n]/, $ref_corpus_lc->{$sent_id};
	for($i=0;$i < scalar(@tab_words_lc);$i++) {
#	foreach $word_lc (@tab_words_lc) {
	    if ((defined $caseSensitive) && (($caseSensitive == 0) || (length($tab_words_lc[$i]) <= $caseSensitive))) {
		$word = $tab_words[$i];
	    } else {
		$word = $tab_words_lc[$i];
	    }
	    if ($word ne "") {
		if (!exists $ref_corpus_index->{$word}) {
		    my @tabtmp;
		    $ref_corpus_index->{$word} = \@tabtmp;
		}
		push @{$ref_corpus_index->{$word}}, $sent_id;
	    }
	}
    }
    print STDERR "\n\tSize of the first selected term list: " . scalar(keys %$ref_corpus_index) . "\n\n";
}

sub print_corpus_index {
    my ($ref_corpus_index) = @_;

    my $word;

    foreach $word (sort keys %$ref_corpus_index) {
	print STDERR "$word\t";
	print STDERR join(", ", @{$ref_corpus_index->{$word}});
	print STDERR "\n";
    }
}

sub _term_Selection2 {
    my ($ref_corpus_index, $ref_termlist, $ref_tabh_idtrm_select) = @_;
    my $counter;
    my $term;
    my @tab_termlex;
    my $i;
    my $word;
    my $sent_id;
    my $word_found = 0;

    warn "Selecting the terms potentialy appearing in the corpus\n";

    my %tabh_numtrm_select;
  
    for($counter  = 0;$counter < scalar @$ref_termlist;$counter++) {
	$term = lc $ref_termlist->[$counter]->[0];
        # XXX - ABREVIATION - XXX
	@tab_termlex = split /[ \-]+/, $term;
	$word_found = 0;
	$i=0; 
	do {
	    $word = $tab_termlex[$i];
	    if (($word ne "") && ((length($word) > 2) || (scalar(@tab_termlex)==1)) && 
		((exists $ref_corpus_index->{$word}))) { #  || (exists $ref_corpus_index->{$word . "s"})
		$word_found = 1;
		if (!exists $ref_tabh_idtrm_select->{$counter}) {
		    my %tabhtmp2;
		    $ref_tabh_idtrm_select->{$counter} = \%tabhtmp2;
		}
		foreach $sent_id (@{$ref_corpus_index->{$word}}) {
		    ${$ref_tabh_idtrm_select->{$counter}}{$sent_id} = 1;
		}
	    }
	    $i++;
	} while((!$word_found) && ($i < scalar @tab_termlex));
    }

    warn "\nEnd of selecting the terms potentialy appearing in the corpus\n";
}

sub term_Selection {
    my ($ref_corpus_index, $ref_termlist, $ref_tabh_idtrm_select, $caseSensitive) = @_;
    my $counter;
    my $term;
    my @tab_termlex;
    my $termCap;
    my @tab_termlexCap;
    my $i;
    my $word;
    my $sent_id;
    my $word_found = 0;

    my @recordedWords;

    warn "Selecting the terms potentialy appearing in the corpus\n";

    my %tabh_numtrm_select;
    
    # warn "caseSensitive: $caseSensitive\n";
    for($counter  = 0;$counter < scalar @$ref_termlist;$counter++) {
	if ((defined $caseSensitive) && (($caseSensitive == 0) || (length($ref_termlist->[$counter]->[0]) <= $caseSensitive))) {
	    $term = $ref_termlist->[$counter]->[0];
	    $termCap = $ref_termlist->[$counter]->[0];
	    # warn "passe\n";
	} else {
	    $term = lc $ref_termlist->[$counter]->[0];
	    $termCap = $ref_termlist->[$counter]->[0];
	}
	# warn "+++> $term ($termCap)\n";
        # XXX - ABREVIATION - XXX
	# @tab_termlex = split /[ \-:]+/, $term;
	@tab_termlex = split /[ ()\',\[\]\?\!:;\/\.\+\-\*\#\{\}\n]+/, $term;
	@tab_termlexCap = split /[ ()\',\[\]\?\!:;\/\.\+\-\*\#\{\}\n]+/, $termCap;
	# @tab_termlex = split /[ \-:]+/, $term;
	# @tab_termlexCap = split /[ \-:]+/, $termCap;
	$word_found = 0;
	$i=0; 
	@recordedWords = ();
	$word = $tab_termlex[$i];
	# warn join(':', @tab_termlex) . " -- " . join(':', @tab_termlexCap) . "\n";
	# warn scalar(@tab_termlex) . " -- " . scalar(@tab_termlexCap) . " ($i)\n";
	while(($i < scalar(@tab_termlex)) && ($i < scalar(@tab_termlexCap)) && 
	      ((($word eq "") || (exists $ref_corpus_index->{$word})) ||
	      ((($caseSensitive == 0) || (length($ref_termlist->[$counter]->[0]) > $caseSensitive)) &&
	       (exists $ref_corpus_index->{$tab_termlexCap[$i]})))
	    ) {
	    if ($word ne "") {
		# warn "---> $term\n";
		push @recordedWords, $word;
	    # } else {
	    # 	warn "--------------------------> $term\n";
	    }
	    $i++;
	    $word = $tab_termlex[$i];
	    # warn "i: $i\n";
	}
	if ($i == scalar(@tab_termlex)) {
	    foreach $word (@recordedWords) {
		if (!exists $ref_tabh_idtrm_select->{$counter}) {
		    my %tabhtmp2;
		    $ref_tabh_idtrm_select->{$counter} = \%tabhtmp2;
		}
		foreach $sent_id (@{$ref_corpus_index->{$word}}) {
		    ${$ref_tabh_idtrm_select->{$counter}}{$sent_id} = 1;
		}
	    }
	}
    }
    warn "Size of the selected list: " . scalar (keys %$ref_tabh_idtrm_select) . "\n";
    # foreach $counter (keys %$ref_tabh_idtrm_select) {
    # 	warn $ref_termlist->[$counter]->[0] . "\n";
    # }

    warn "\nEnd of selecting the terms potentialy appearing in the corpus\n";
}

sub term_tagging_offset {
    my ($ref_termlist, $ref_regex_termlist, $ref_tabh_idtrm_select, $ref_tabh_corpus, $offset_tagged_corpus_name, $caseSensitive) = @_;
    my $counter;
    my $term_regex;
    my $sent_id;
    my $line;

    # XXX - ABREVIATION - XXX => regex

    warn "Term tagging\n";

    open TAGGEDCORPUS, ">>$offset_tagged_corpus_name" or die "$0: $offset_tagged_corpus_name: No such file\n";

    binmode(TAGGEDCORPUS, ":utf8");

    foreach $counter (keys %$ref_tabh_idtrm_select) {
	$term_regex = $ref_regex_termlist->[$counter];
	foreach $sent_id (keys %{$ref_tabh_idtrm_select->{$counter}}){
	    $line = $ref_tabh_corpus->{$sent_id};
	    print STDERR ".";
	    
	    if ((((defined $caseSensitive) && (($caseSensitive == 0) || (length($ref_termlist->[$counter]->[0]) <= $caseSensitive))) &&
		 ($line =~ /[,.?!:;\/ \n\-\/\*'\#\{\}\(\)\[\]\+]($term_regex)[,.?!:;\/ \n\-\/\*'\#\(\)\[\]\{\}\+]/)) || 
		(((!defined $caseSensitive) || ($caseSensitive < 0) || (length($ref_termlist->[$counter]->[0]) > $caseSensitive)) && 
		 ($line =~ /[,.?!:;\/ \n\-\/\*'\#\{\}\(\)\[\]\+]($term_regex)[,.?!:;\/ \n\-\/\*'\#\(\)\[\]\{\}\+]/i))) {
		printMatchingTerm(\*TAGGEDCORPUS, $ref_termlist->[$counter], $sent_id);
	    }
	    if ((((defined $caseSensitive) && (($caseSensitive == 0) || (length($ref_termlist->[$counter]->[0]) <= $caseSensitive))) &&
		 ($line =~ /^($term_regex)[,.?!:;\/ \n\-\/\*'\#\(\)\[\]\{\}\+]/i)) || 
		(((!defined $caseSensitive) || ($caseSensitive < 0) || (length($ref_termlist->[$counter]->[0]) > $caseSensitive)) && 
		 ($line =~ /^($term_regex)[,.?!:;\/ \n\-\/\*'\#\(\)\[\]\{\}\+]/i))) {
		printMatchingTerm(\*TAGGEDCORPUS, $ref_termlist->[$counter], $sent_id);
	    }
	    if ((((defined $caseSensitive) && (($caseSensitive == 0) || (length($ref_termlist->[$counter]->[0]) <= $caseSensitive))) &&
		 ($line =~ /[,.?!:;\/ \n\-\/\*'\#\(\)\[\]\{\}\+]($term_regex)$/)) ||
		(((!defined $caseSensitive) || ($caseSensitive < 0) || (length($ref_termlist->[$counter]->[0]) > $caseSensitive)) && 
		 ($line =~ /[,.?!:;\/ \n\-\/\*'\#\(\)\[\]\{\}\+]($term_regex)$/i))) {
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
    print $descriptor join("\t", @$ref_matching_term);
    print $descriptor "\n";

}


sub term_tagging_offset_tab {
    my ($ref_termlist, $ref_regex_termlist, $ref_tabh_idtrm_select, $ref_tabh_corpus, $ref_tab_results, $caseSensitive) = @_;
    my $counter;
    my $term_regex;
    my $sent_id;
    my $line;
    my $i;
    my $size_termselect = scalar(keys %$ref_tabh_idtrm_select);

    $i = 0;

    # XXX - ABREVIATION - XXX => regex
#    warn "====> $caseSensitive\n";
    
    foreach $counter (keys %$ref_tabh_idtrm_select) {
  	printf STDERR "Term tagging... %0.1f%%\r", ($i/$size_termselect)*100 ;
	$term_regex = $ref_regex_termlist->[$counter];
	# warn "counter: $counter ($term_regex)\n";

	foreach $sent_id (keys %{$ref_tabh_idtrm_select->{$counter}}){
	    $line = $ref_tabh_corpus->{$sent_id};

	    # warn "$line\n$term_regex\n";

	    if ((((defined $caseSensitive) && (($caseSensitive == 0) || (length($ref_termlist->[$counter]->[0]) <= $caseSensitive))) &&
		 ($line =~ /[,.?!:;\/ \n\-\/\*'\#\{\}\(\)\[\]\+](?<term>$term_regex)[,.?!:;\/ \n\-\/\*'\#\(\)\[\]\{\}\+]/s)) ||
		(((!defined $caseSensitive) || ($caseSensitive < 0) || (length($ref_termlist->[$counter]->[0]) > $caseSensitive)) && 
		 ($line =~ /[,.?!:;\/ \n\-\/\*'\#\{\}\(\)\[\]\+](?<term>$term_regex)[,.?!:;\/ \n\-\/\*'\#\(\)\[\]\{\}\+]/is))) {
 		printMatchingTerm_tab($ref_termlist->[$counter], $+{term},  $sent_id, $ref_tab_results);
	    }
 	    if ((((defined $caseSensitive) && (($caseSensitive == 0) || (length($ref_termlist->[$counter]->[0]) <= $caseSensitive))) &&
		 ($line =~ /^(?<term>$term_regex)[,.?!:;\/ \n\-\/\*'\#\(\)\[\]\{\}\+]/s)) ||
		(((!defined $caseSensitive) || ($caseSensitive < 0) || (length($ref_termlist->[$counter]->[0]) > $caseSensitive)) && 
		 ($line =~ /^(?<term>$term_regex)[,.?!:;\/ \n\-\/\*'\#\(\)\[\]\{\}\+]/is))) {
		printMatchingTerm_tab($ref_termlist->[$counter], $+{term}, $sent_id, $ref_tab_results);
	    }
	    if ((((defined $caseSensitive) && (($caseSensitive == 0) || (length($ref_termlist->[$counter]->[0]) <= $caseSensitive))) &&
		 ($line =~ /[,.?!:;\/ \n\-\/\*'\#\(\)\[\]\{\}\+](?<term>$term_regex)$/s)) ||
		(((!defined $caseSensitive) || ($caseSensitive < 0) || (length($ref_termlist->[$counter]->[0]) > $caseSensitive)) && 
		 ($line =~ /[,.?!:;\/ \n\-\/\*'\#\(\)\[\]\{\}\+](?<term>$term_regex)$/is))) {
		printMatchingTerm_tab($ref_termlist->[$counter], $+{term}, $sent_id, $ref_tab_results);
	    }
	}
	$i++;
    }
    print STDERR "\n";

#########################################################################################################
    warn "\nEnd of term tagging\n";
}

sub printMatchingTerm_tab() {
    my ($ref_matching_term, $term, $sent_id, $ref_tab_results) = @_;

    my $tmp_line = "";
    my $tmp_key;

    # warn "\nOK\n";

    if (ref($ref_tab_results) eq "ARRAY") {
	$tmp_line .= "$sent_id\t";
 	$tmp_line .= join ("\t", @$ref_matching_term);
	push @$ref_tab_results, $tmp_line;
    } else {
	if (ref($ref_tab_results) eq "HASH") {
	    my @tab_tmp;
 	    $term =~ s/\\([\-\+\(\)\{\}])/$1/og;
	    $tmp_key .= $sent_id . "_";
	    $tmp_key .= $term;

	    push @tab_tmp, $sent_id;
	    push @tab_tmp, @$ref_matching_term;

	    # if (!exists $ref_tab_results->{$tmp_key}) {
	    $ref_tab_results->{$tmp_key} = \@tab_tmp;
	    # } else {
	    # 	foreach $refmatch (@{$ref_tab_results->{$tmp_key}}) {
		    
	    # 	}
	    # }
	}
    }
}

1;

__END__

=head1 NAME

Alvis::TermTagger - Perl extension for tagging terms in a text

=head1 SYNOPSIS

use Alvis::TermTagger;

Alvis::TermTagger::termtagging($text, $termlist, $outputfile);

or 

Alvis::TermTagger::termtagging($text, $termlist, $outputfile, $lemmatised_text);



=head1 DESCRIPTION

This module is used to tag a text with terms (either with inflected or
lemmatised form of their words). The text or the text corpus
(C<$text>) is a file with one sentence per line. Term list
(C<$termlist>) is a file containing one term per line. For each term,
additionnal information (as canonical form, a semantic tag and the
lemmatised word of the term) can be given after the first column. This
information can be separated by either a colon, either by a vertical
bar. Each line of the output file (C<$outputfile>) contains the
sentence number, the term, additional information, all separated by a
tabulation character. The lemmatised text (C<$lemmatised_text>) is
build as the concatenation of the lemma of the word of the corpus;

This module is mainly used in the Alvis NLP Platform.

=head1 METHODS



=head2 termtagging()

    termtagging($corpus_filename, $term_list_filename, $output_filename, $lemmatised_corpus_filename, $caseSensitive);

This is the main method of module. It loads the term list
(C<$term_list_filename>) and tags the text corpus
(C<$corpus_filename>). It produces the list of matching terms and the
sentence offset (and additional information given in the input file)
where the terms can be found. The file C<$output_filename> contains
this output.  To look up the lemmatised term (as a concatenation of
lemmatised word), the lemmatised corpus C<$lemmatised_corpus_filename>
has to be specified as fourth argument of the method.

The parameter C<$caseSensitive> indicates if the term matching is case
sensitive (value greater or equal to 0) or insensitive ((value
strictly lesser than 0). If the value of C<$caseSensitive> is equal to
0, the case sensitive match is carried out for any terms. If the value of
C<$caseSensitive> is strictly greater than 0, the case sensitive match
is carried out only for the terms with a number of characters lesser
or equal to C<$caseSensitive>.


=head2 load_TermList()

    load_TermList($term_list_filename,\@term_list);

This method loads the term list (C<$term_list_filename> is the file
name) in the array given by reference (C<\@term_list>). Each element
of term list contains a reference to a two element array (the term and
its canonical form).


=head2 get_Regex_TermList()

    get_Regex_TermList(\@term_list, \@regex_term_list, \@ref_regex_lemmaWordtermlist);

This method generates the regular expression from the term list
(C<\@term_list>). stored in the specific array
(C<\@regex_term_list>). C<\@ref_regex_lemmaWordtermlist> records the
regular expression for the term lemma.


=head2 load_Corpus()

    load_Corpus($corpus_filename\%corpus, \%lc_corpus);

This method loads the corpus (C<$corpus_filename>) in hashtable
(C<\%corpus>) and prepares the corpus in lower case (recorded in a
specific hashtable, C<\%lc_corpus>)



=head2 corpus_Indexing()

    corpus_Indexing(\%lc_corpus, \%corpus, \%corpus_index, $caseSensitive);

This method indexes the lower case version of the corpus
(C<\%lc_corpus>) or the normal case version of the corpus according to
the value of the case sensitive parameter (C<$caseSensitive>). The
words are stored in the index C<\%corpus_index> (the index is a
hashtable given by reference).

=head2 print_corpus_index()

    print_corpus_index(\%corpus_index);

This method prints on STDERR the corpus index C<\%corpus_index>.

=head2 term_Selection()

    term_Selection(\%corpus_index, \@term_list, \%idtrm_select, $caseSensitive);

This method selects the terms from the term list (C<\@term_list>)
potentially appearing in the corpus (that is the indexed corpus,
C<\%corpus_index>). Results are recorded in the hash table
C<\%idtrm_select>.

The parameter C<$caseSensitive> indicates if the term matching is case
sensitive (value greater or equal to 0) or insensitive ((value
strictly lesser than 0). If the value of C<$caseSensitive> is equal to
0, the case sensitive match is carried out for any terms. If the value of
C<$caseSensitive> is strictly greater than 0, the case sensitive match
is carried out only for the terms with a number of characters lesser
or equal to C<$caseSensitive>.


=head2 term_tagging_offset()

    term_tagging_offset(\@term_list, \@regex_term_list, \%idtrm_select, \%corpus, $output_filename, $caseSensitive);

This method tags the corpus C<\%corpus> with the terms (issued from
the term list C<\@term_list>, C<\@regex_term_list> is the term list
with regular expression), and selected in a previous step
(C<\%idtrm_select>). Resulting selected terms are recorded with their
offset, and additional information in the file C<$output_filename>.

The parameter C<$caseSensitive> indicates if the term matching is case
sensitive (value greater or equal to 0) or insensitive ((value
strictly lesser than 0). If the value of C<$caseSensitive> is equal to
0, the case sensitive match is carried out for any terms. If the value of
C<$caseSensitive> is strictly greater than 0, the case sensitive match
is carried out only for the terms with a number of characters lesser
or equal to C<$caseSensitive>.

=head2 term_tagging_offset_tab()

    term_tagging_offset_tab(\@term_list, \@regex_term_list, \%idtrm_select, \%corpus, \@tab_results, $caseSensitive);

or 

    term_tagging_offset_tab(\@term_list, \@regex_term_list, \%idtrm_select, \%corpus, \%tabh_results, $caseSensitive);

This method tags the corpus C<\%corpus> with the terms (issued from
the term list C<\@term_list>, C<\@regex_term_list> is the term list
with regular expression), and selected in a previous step
(C<\%idtrm_select>). Resulting selected terms are recorded with their
offset, and additional information in the array C<@tab_results>
(values are sentence id, selected terms and additional information
separated by tabulation) or in the hashtable C<%tabh_results> (keys
form is "sentenceid_selectedterm", values are an array reference
containing sentence id, selected terms and additional ifnormation).

The parameter C<$caseSensitive> indicates if the term matching is case
sensitive (value greater or equal to 0) or insensitive ((value
strictly lesser than 0). If the value of C<$caseSensitive> is equal to
0, the case sensitive match is carried out for any terms. If the value of
C<$caseSensitive> is strictly greater than 0, the case sensitive match
is carried out only for the terms with a number of characters lesser
or equal to C<$caseSensitive>.

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

Thierry Hamon <thierry.hamon@univ-paris13.fr>

=head1 LICENSE

Copyright (C) 2006 by Thierry Hamon

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.6 or,
at your option, any later version of Perl 5 you may have available.


