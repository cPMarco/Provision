#!/usr/bin/perl
use strict;
use warnings;

my $v = '';
if ( grep {/v/} @ARGV ) {
    $v = 'v';
};

my $dir_for_files = "$ENV{HOME}/tmp/provision_files";
my $dir_to_keep = "$ENV{HOME}/.provisioned";
unless ( -d $dir_to_keep ){
    system( "mkdir $dir_to_keep" );
}

bash_custom_refs();

system( 'tar', '-C', $ENV{HOME}, "-x${v}f",
    "$ENV{HOME}/transferred_by_provision_script.tar" );

chomp( my @files = grep { !/^\.*$/ } `ls -a $dir_for_files` );
for my $file (@files) {
    if ( $file =~ /ssh_key/ ) {
        authorize_key($file);
    }
    elsif ( $file =~ /^aaHIDE_(.*)/ ) {
        if ( $1 eq '' ){
            print "\n[error] Filename empty\n" if ( $1 eq '' );
            next
        }
        replace_file( $file, $dir_to_keep, $1 );
    }
    elsif ( $file =~ /^zzRUN_([A-Z]+)_(.*)/ ) {
        if ( $1 =~ /BASH/ ) {
            system("sh $dir_for_files/$file");
        }
        elsif ( $1 =~ /PERL/ ) {
            system("perl $dir_for_files/$file");
        }
        replace_file( $file, $dir_to_keep );
    }
    else {    # add non-default files above here
        replace_file( $file, "$ENV{HOME}/" );
    }
}

print "\nFile expansion on the remote server is complete.\n";
if ( $v eq '' ) {
    print "This message does not indicate success (hint: -v).\n\n";
}


sub bash_custom_refs {
    my $add_to_startups = <<'EOF';

if [ -f ~/.bash_custom ]; then
        . ~/.bash_custom
fi
EOF
    ensure_bash_custom_ref( '.bashrc',       $add_to_startups );
    ensure_bash_custom_ref( '.bash_profile', $add_to_startups );
}

sub ensure_bash_custom_ref {
    my ( $filename, $add_to_startups ) = @_;
    my $file = "$ENV{HOME}/$filename";
    my $already_has_it = !system( 'grep', '-q', 'bash_custom', $file );
    if ( !$already_has_it ) {
        open( my $fh, '>>', $file ) or die "Couldn't open file $!";
        print $fh $add_to_startups;
    }
}

sub replace_file {
    my ( $name_orig, $location, $change_name_to ) = @_;
    $change_name_to = '' unless defined $change_name_to; # ugly
    my $filename;
    if ( $change_name_to eq '' ) {
        $filename = $name_orig;
    }
    else {
        $filename = $change_name_to;
    }
    my $full_path_dest = "$location/$filename";
    # if file already exists, save as file.bak
    if ( -e $dir_to_keep && -e $full_path_dest ) {
        system( "cat $full_path_dest > $dir_to_keep/${filename}.bak" );
    }
    system( 'cp', "$dir_for_files/$name_orig", $full_path_dest );
}

sub authorize_key {
    my $key_file = shift;
    if ( !-d "$ENV{HOME}/.ssh" ) {
        system( 'mkdir', "$ENV{HOME}/.ssh" );
        system( 'chmod', '700', "$ENV{HOME}/.ssh" );
    }
    system( "cat $dir_for_files/$key_file >> $ENV{HOME}/.ssh/authorized_keys" );
}

## Cleanup
system( 'rm', '-rf', "$dir_for_files" );
system( 'rm', "$ENV{HOME}/transferred_by_provision_script.tar" );
system( 'rm', "$ENV{HOME}/provision_expand.pl" );
system( "mv -v $ENV{HOME}/.prov_manifest $dir_to_keep/prov_manifest" );
