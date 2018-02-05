#----------------------------------------------------------------------
# copyright (C) 1999-2005 Mitel Networks Corporation
# Copyright (C) 2012 Nethesis srl
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#               
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#               
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307  USA
# 
# Technical support for this program is available from Mitel Networks 
# Please visit our web site www.mitel.com/sme/ for details.
#----------------------------------------------------------------------
package esmith::Build::CreateLinks;

use strict;
use warnings;
use Exporter;
use File::Basename;
use File::Path;

our @ISA = qw(Exporter);
our @EXPORT = qw();
our @EXPORT_OK = qw(
	safe_symlink panel_link admin_common_link 
	event_link service_link_enhanced
	safe_touch templates2events
        validator_link event_templates event_actions
        validator_actions event_services
	);
our %EXPORT_TAGS = (
	all => [ qw!safe_symlink panel_link admin_common_link
                    event_link service_link_enhanced validator_link
		    safe_touch templates2events event_templates event_actions
                    validator_actions event_services! ]
        );
our $VERSION = '6.103';

=head1 NAME

esmith::Build::CreateLinks - A library for creating symlinks during rpm construction.

=head1 SYNOPSIS

    use esmith::Build::CreateLinks qw(:all);
  
    safe_symlink("../../../functions/$function", "$cgibin/$function")

=head1 DESCRIPTION

=cut

=head2 safe_symlink

This function works like symlink(), but if the directory being linked to does
not exist, it will create it. 

   ie. safe_symlink("../../../functions/$function", "$cgibin/$function")

=cut

sub safe_symlink($$) {
    my ($from, $to) = @_;
    mkpath(dirname($to));
    unlink($to) if -f $to;
    symlink($from, $to)
	or die "Can't create symlink from $from to $to: $!";
    print $to . "\n";
}

=head2 panel_link

This function creates a link to a web panel. 

   ie. 
    my $panel = "manager";
    panel_link("tug", $panel);

=cut

sub panel_link($$)
{
    my ($function, $panel) = @_;
    my $cgibin = "root/etc/e-smith/web/panels/$panel/cgi-bin";

    safe_symlink("../../../functions/$function",
            "$cgibin/$function")
}

=head2 admin_common_link

This function creates a symlink from the common manager directory to a file in
the functions directory.

=cut

sub admin_common_link($)
{
    my ($function) = @_;
    safe_symlink("../../../functions/$function",
        "root/etc/e-smith/web/panels/manager/common/$function");
}

=head2 event_link

This function creates a symlink from an action's ordered location in an
event directory to its action script.

   ie.
    my $event = "tug-update";
    event_link("tug-conf", $event, "10");
    event_link("conf-masq", $event, "20");
    event_link("adjust-masq", $event, "30");
    event_link("tug-restart", $event, "40");

=cut

sub event_link($$$)
{
    my ($action, $event, $level) = @_;

    safe_symlink("../actions/${action}",
        "root/etc/e-smith/events/${event}/S${level}${action}");
}


=head2 validator_link

This function creates a symlink from an action's ordered location in a
validator directory to its action script.

   ie.
    my $validator = "user-name";
    validator_link("uniq-accountname", $validator, "10");
    validator_link("max-users", $validator, "20");

=cut

sub validator_link($$$)
{
    my ($action, $validator, $level) = @_;

    safe_symlink("../actions/${action}",
        "root/etc/e-smith/validators/${validator}/S${level}${action}");
}


=head2 validator_actions($validatorName, @action_specs)

Create links to actions for the given validator. @actions_specs is a
list of pairs Action => Priority. E.g

  validator_actions('validator-name', 'act1' => '10', 'act2' => '20', ..);

See also validator_link().

=cut 

sub validator_actions
{
    my ($validator, @action_specs) = @_;

    while(scalar @action_specs > 0) {
	my $action = shift @action_specs;
	my $priority = shift @action_specs;
	validator_link($action, $validator, $priority);
    }
}

=head2 service_link_enhanced

This function creates a symlink from a SysV init start or kill link in a
runlevel to e-smith-service, a wrapper that is config db aware.

   ie.
    safe_symlink("daemontools", "root/etc/rc.d/init.d/tug");
    service_link_enhanced("tug", "S85", "7");
    service_link_enhanced("tug", "K25", "6");
    service_link_enhanced("tug", "K25", "0");

=cut

sub service_link_enhanced($$$)
{
    my ($service, $level, $rc) = @_;

    $rc = 7 unless defined $rc;
    $level =~ /[^\d]/ or $level = "S${level}";
    safe_symlink("/etc/rc.d/init.d/e-smith-service",
        "root/etc/rc.d/rc${rc}.d/${level}${service}");
}

=head2 safe_touch

This function creates an empty file, but first creates any enclosing directories.  
For example:

  safe_touch("a/b/c/d");

will create any of the directories "a", "a/b", "a/b/c" which don't exist, then create
an empty file "a/b/c/d".

=cut

sub safe_touch
{
    my ($path) = @_;
    my ($file, $dir) = fileparse $path;
    unless (-d $dir)
    {
	mkpath $dir or die "Could not create dir $dir: $!";
    }
    open(F, ">$path") or die "Could not open/create file $path: $!";
    close(F) or die "Could not close file $path: $!";
    print $path . "\n";
}

=head2 templates2events

This function creates a file tree (of empty files) which is used by the
generic_template_expand action to determine which templates need to
be expanded for a particular event. Takes one file argument and a
list of event names, e.g.

 templates2events("/etc/some/file", "event1", "event2", ...);

=cut
sub templates2events
{
    my ($path, @events) = @_;
    
    foreach (@events)
    {
	safe_touch "root/etc/e-smith/events/$_/templates2expand/$path";
    }
}

=head2 event_templates($event, @paths)

This function is similar to templates2events(): determines the list of templates to be expanded for the given an event name. E.g.

 event_templates("event1", "/etc/some/file1", "/etc/some/file2, ...);

=cut
sub event_templates
{
    my ($event, @paths) = @_;

    foreach (@paths) 
    {
	safe_touch "root/etc/e-smith/events/$event/templates2expand/$_";
    }
}

=head2 event_actions($event, @action_specs)

Create links to actions for the given event. @actions_specs is a list of pairs Action => Priority. E.g

  event_actions('myevent', 'act1' => '10', 'act2' => '20', ..);

See also event_link().

=cut
sub event_actions
{
    my ($event, @action_specs) = @_;

    while(scalar @action_specs > 0) {
	my $action = shift @action_specs;
	my $priority = shift @action_specs;
	event_link($action, $event, $priority);
    }

}


=head2 event_services($event, @service_specs) 

Create links for the given $event in services2adjust/
subdirectory. @service_specs is a list of pairs Service =>
LinkDestination

  event_services('myevent', 'sshd' => 'restart', 'samba' => 'reload')

See also safe_symlink().

=cut
sub event_services
{
    my ($event, @action_specs) = @_;

    while(scalar @action_specs > 0) {
	my $service = shift @action_specs;
	my $action = shift @action_specs;
        my $dir = 'root/etc/e-smith/events/' . $event . '/services2adjust/';
        File::Path::make_path($dir);
        open(my $fh, '>', $dir . $service);
        print $fh "$action\n";
        close $fh;
        print $dir . $service . "\n";
    }    
}

=head1 AUTHOR

=over 4

=item - SME Server Developers <bugs@e-smith.com>

=item - Nethesis srl www.nethesis.it <bugs@nethesis.it>

=back

=cut

1;
