#!/usr/bin/perl
#
# Input: Canon CR2 raw files or already converted PGM files
#

use strict;

our $PROGRAM = 'scribus-crop';
our $VERSION = '0.1';

use Getopt::Std;
use FileHandle;
use DirHandle;
use Data::Dumper;
use List::Util;
use File::Basename;
use Encode qw(encode decode);

# extra packages, must be installed on ActivePerl using ppm
use Math::Round;
use XML::LibXML;


# ImageMagick commands
our $MOGRIFY = "magick mogrify -quality 95 -crop %dx%d+%d+%d \"%s\"";



##### main ###################################################################
our ($opt_v, $opt_q, $opt_d, $opt_h, );
getopts('vqdh');

if($opt_h or $#ARGV < 0) {
    print STDERR
      "\n",
      "$PROGRAM --- Scribus image cropper\n",
      "\n",
      "Usage:   $PROGRAM [-vqdh] FILE.SLA ...\n",
      "\n",
      "Options:  -v        verbose\n",
      "          -q        quiet, ie no messages\n",
      "          -d        debug\n",
      "          -h        this help\n",
      "\n";
    exit 1;
}


$SIG{PIPE} = 'IGNORE';

do_args(@ARGV);


exit 0;



sub do_args {
    for my $a (@_) {
	do_scribus($a);
    }
}



sub do_scribus {
    my ($file) = @_;

    print "$PROGRAM: processing file $file\n" if($opt_v);

    my $parser = XML::LibXML->new();
    my $doc    = $parser->parse_file($file);

    for my $obj ($doc->findnodes('/SCRIBUSUTF8NEW/DOCUMENT/PAGEOBJECT[@PTYPE=2]')) {
	do_pageobj($obj);
#####
#exit;
#####
    }

    # save changed XML
    my ($name, $dir, $ext) = fileparse($file, qr/\.[^.]*/);
    my $new = "$dir$name-cropped$ext";
    print "$PROGRAM: writing changed file $new\n" if($opt_v);
    $doc->toFile($new, 1);
}


# Beispielbild:
# pfile = bilder/06-Gamsberg/book-122-full-Gamsberg_Plateau_#9.jpg
#   units: x=-2948.03149606299 y=0 scx=0.24 scy=0.24 w=692.9886614 h=594.0056693
#   cm:    x=-24.9600 y=0.0000 w=24.4471 h=20.9552
#   pixel: x=-2948 y=0 w=2887 y=2475

# ImageMagick: 
# mogrify -quality 95 -crop 2887x2475+2948+0
#         bilder\06-Gamsberg\book-122-full-Gamsberg_Plateau_#9.jpg

sub do_pageobj {
    my ($obj) = @_;

    my $scx    = $obj->getAttribute("LOCALSCX");# image scaling = 0.24 = 72/300
    my $scy    = $obj->getAttribute("LOCALSCY");# for 300 dpi images
    my $x      = $obj->getAttribute("LOCALX");  # x offset pixel
    my $y      = $obj->getAttribute("LOCALY");  # y offset pixel
    my $pfile  = $obj->getAttribute("PFILE");	# image file name
    my $ptype  = $obj->getAttribute("PTYPE");	# type 2 = image
    my $width  = $obj->getAttribute("WIDTH");	# obj=image width
    my $height = $obj->getAttribute("HEIGHT");	# obj=image height

    if($pfile) {
	if($opt_d) {
	    print "pfile = $pfile\n",
	    "  units: x=$x y=$y scx=$scx scy=$scy w=$width h=$height\n";
	    print "  cm:    x=", pxl2cm($x, $scx), " y=", pxl2cm($y, $scy),
	    " w=", sla2cm($width), " h=", sla2cm($height), "\n";
	    print "  pixel: x=", round($x), " y=", round($y),
	    " w=", sla2pxl($width, $scx), " h=", sla2pxl($height, $scy), "\n";
	}

	my $dx = round(-$x);
	my $dy = round(-$y);
	return unless($dx>=0);
	## skip some files
	## images exported from LR with 3:2 aspect, no shift
	return if($pfile =~ /book-\d+-3x2-/ && $dx==0 && $dy==0);

	## fix filename for Windows, CP 850 (chcp)
	my $file = encode("cp850", $pfile);

	my $cmd = sprintf $MOGRIFY, sla2pxl($width, $scx),
	sla2pxl($height, $scy), round(-$x), round(-$y), $file;

	print $cmd, "\n";

###print "LOCAL Y != 0 !!!\n", exit if($y);
	# set LOCALX to 0
	$obj->setAttribute("LOCALX", 0);

    }
}


# convert scribus units (1 unit == 1/72 inch)
sub sla2cm {
    return sprintf "%.4f", $_[0] / 72.0 * 2.54;
}

sub pxl2cm {
    return sprintf "%.4f", $_[0] * $_[1] / 72.0 * 2.54;
}

sub sla2pxl {
    return round($_[0] / $_[1]);
}


sub do_dir {
    my ($dir) = @_;

    my $dh = DirHandle->new($dir)
	|| die "$PROGRAM: can't open directory $dir: $!";

    print "$PROGRAM: processing dir $dir\n" if($opt_d);

    my @files = sort grep !/^\./, $dh->read;
    my $f;

    for $f (@files) {
	do_file("$dir/$f");
    }
}



sub do_file {
    my ($file) = @_;

    print "$PROGRAM: processing file $file\n" if($opt_d);

}



##### classes ################################################################

package MyClass;
use File::Basename;

sub new {
    my $class = shift;

    my $self = {};
    bless($self, $class);

    # init

    return $self;
}

sub get_data {
    my $self = shift;

    return $self->{data};
}
