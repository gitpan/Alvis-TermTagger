#!/usr/bin/perl

#######################################################################
#
# Last Update: 01/09/2003 (mm/dd/yyyy date format)
# 
# Copyright (C) 2002 Thierry Hamon
#
# Written by thierry.hamon@lipn.univ-paris13.fr
#
# Author : Thierry Hamon
# Email : thierry.hamon@lipn.univ-paris13.fr
# URL : http://www-lipn.univ-paris13.fr/~hamon
#
########################################################################

=head1 NAME

TermTagger.pl -- A Perl script for tagging corpus with terms

=head2 SYNOPSIS

B<TermTagger.pl> corpus termlist selected_term_list

=head1 DESCRIPTION


This script tags a corpus with terms. Corpus (C<corpus>) is a file
with one sentence per line. Term list (C<termlist>) is a file
containing one term per line. For each term, additionnal information
can be given after a column. Each line of the output file
(C<selected_term_list>) contains the sentence number and the term
separated by a tabulation character.

This script is mainly used in the Alvis NLP Platform.

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

use strict;
use Alvis::TermTagger;

Alvis::TermTagger::termtagging($ARGV[0], $ARGV[1], $ARGV[2]);



