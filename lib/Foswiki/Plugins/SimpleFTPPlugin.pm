# See bottom of file for default license and copyright information

package Foswiki::Plugins::SimpleFTPPlugin;

use strict;
use warnings;

use Foswiki::Func    ();    # The plugins API
use Foswiki::Plugins ();    # For the API version

use Net::FTP;

use version; our $VERSION = version->declare("v0.1.0");
our $RELEASE = '0.1.0';

our $SHORTDESCRIPTION =
  'Simple plugin to allow FTP upload of a particular Foswiki topic page.';

our $NO_PREFS_IN_TOPIC = 1;

my $ftpServer;
my $ftpUsername;
my $ftpPassword;
my $ftpDestinationPath;
my $tempFile = $Foswiki::cfg{WorkingDir} . '/tmp/simpleftpplugin.tmp';
my $user;

sub initPlugin {

    my ( $topic, $web, $user, $installWeb ) = @_;

    $user = $_[2];

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.2 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between ',
            __PACKAGE__, ' and Plugins.pm' );
        return 0;
    }

    $ftpServer = $Foswiki::cfg{Plugins}{SimpleFTPPlugin}{Server}
      || 'ftp.example.com';
    $ftpUsername = $Foswiki::cfg{Plugins}{SimpleFTPPlugin}{Username}
      || 'anonymous';
    $ftpPassword = $Foswiki::cfg{Plugins}{SimpleFTPPlugin}{Password}
      || 'anonymous';
    $ftpDestinationPath =
      $Foswiki::cfg{Plugins}{SimpleFTPPlugin}{DestinationPath} || '/';

    Foswiki::Func::registerRESTHandler( 'ftpupload', \&ftpUpload,
        http_allow => 'GET,POST' );

    # Plugin correctly initialized
    return 1;
}

sub ftpUpload {

    my ( $session, $subject, $verb, $response ) = @_;

    my $query = $session->{request};

    my $server   = $query->{param}->{ftpserver}[0]   || $ftpServer;
    my $username = $query->{param}->{ftpusername}[0] || $ftpUsername;
    my $password = $query->{param}->{ftppassword}[0] || $ftpPassword;
    my $dstPath  = $query->{param}->{dstpath}[0]     || $ftpDestinationPath;
    my $web      = $query->{param}->{srcweb}[0];
    my $topic    = $query->{param}->{srctopic}[0];
    my $dstFilename = $query->{param}->{dstfilename}[0];

    if ( !defined $web ) {
        return "No web specified: please specify 'srcweb' parameter in URL.\n";
    }
    if ( !defined $topic ) {
        return
          "No topic specified: please specify 'srctopic' parameter in URL.\n";
    }

    if (
        !Foswiki::Func::checkAccessPermission(
            'VIEW', $user, undef, $topic, $web, undef
        )
      )
    {
        return
"You do not have VIEW access on the specified topic: please specify a different topic or change the specified topic's permissions.\n";
    }

    my ( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );

    my @textLines = split( /\n/, $text );

    my $content = '';
    foreach (@textLines) {
        if ( /\%STARTFTPCONTENT\%/ .. /\%ENDFTPCONTENT\%/ ) {
            if ( /\%STARTFTPCONTENT\%/ || /\%ENDFTPCONTENT\%/ ) { next; }
            $content = $content . "$_\n";
        }
    }

    open( my $fh, '>', $tempFile )
      or return "Unable to open temporary file '$tempFile': $!\n";
    print $fh $content;
    close($fh)
      or return "Unable to close temporary file '$tempFile': $!\n";

    if ( !defined $dstFilename ) {
        $dstFilename = 'output.html';
    }

    my $result =
      uploadContent( $server, $username, $password, $web, $topic, $dstPath,
        $dstFilename );

    Foswiki::Func::writeWarning "$result\n";

    return "$result\n\n";

}

sub uploadContent {

    my ( $server, $username, $password, $web, $topic, $dstPath, $dstFilename )
      = @_;

    my $ftp = Net::FTP->new($server)
      or return "Could not connect to $server: " . $@ . "\n";

    $ftp->login( $username, $password )
      or return "Could not login: " . $ftp->message . "\n";

    $ftp->cwd($dstPath)
      or return "Could not change working directory: " . $ftp->message . "\n";

    $ftp->put( $tempFile, $dstFilename )
      or return "PUT failed: " . $ftp->message . "\n";

    $ftp->quit;

    return "Successfully uploaded content to $server:$dstPath/$dstFilename.\n";

}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Author: AlexisHazell

Copyright (C) 2008-2013 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 3
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
