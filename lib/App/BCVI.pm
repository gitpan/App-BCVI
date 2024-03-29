package App::BCVI;
{
  $App::BCVI::VERSION = '3.09';
}

# This file is documentation only - all code is in bin/bcvi.  Package name is
# only mentioned here to claim the namespace on CPAN/PAUSE.

1;

__END__

=head1 NAME

App::BCVI - Back-channel vi, a shell utility to proxy commands back over ssh

=head1 DESCRIPTION


The C<bcvi> utility works with SSH to allow commands issued on the SSH server
host to be sent I<back> to the SSH client host over a port-forwarded 'back
channel'.  A few examples might help clarify how C<bcvi> is used (note you can
read an illustrated version of the following examples at:
L<http://sshmenu.sourceforge.net/articles/bcvi/>):

=head2 Example 1

A user 'sally' opens a gnome-terminal window on her workstation and uses the
SSH command to log in to the host 'pluto'.  She then types a command to edit a
file:

  ~$ ssh pluto
  sally@pluto:~$ vi .bashrc

Through the magic of C<bcvi>, the result is that the file is opened for editing
in a 'gvim' editor window on Sally's workstation.  Note, this does B<not> use
X-forwarding.  The GUI editor process is running on Sally's workstation.  The
file is copied transparently to and from the server pluto using scp (via gvim's
'netrw' network transport layer).

Compared to running vim on the remote server in the terminal window, C<bcvi>
provides these advantages to Sally:

=over 4

=item *

gvim on Sally's workstation has all her preferred key mappings, custom macros,
plugins and scripts

=item *

gvim is a GUI app that responds to mouse input for scrolling, selecting text,
copying and pasting

=item *

gvim knows when Sally is pasting so it disables autoindent automatically and
avoids the dreaded stair-step effect often seen when pasting into vim in a
terminal window

=item *

because gvim is running locally (rather than via X-forwarding) the application
loads quickly and is responsive to user input

=item *

no GUI apps or libraries need to be installed on the server*

=back

*You might argue that C<bcvi> itself will need to be installed on the server,
but Sally can do that from her workstation with one simple command (and no need
for root access):

  ~$ bcvi --install pluto
  Creating ~/bin directory on pluto
  Copying bcvi to remote bin directory on pluto
  Creating plugins directory on pluto
  Copying plugin files to pluto
  Added bcvi commands to /home/sally/.bashrc

=head2 How Example 1 Worked

The C<bcvi> utility was not responsible for copying files to and from the
server 'pluto' (gvim can already do that).  Rather, C<bcvi> was used to
establish a communications channel from 'pluto' back to Sally's workstation.
This back channel was used to send a message triggering the launching of gvim
and the loading of the specified file.

The example above assumed:

=over 4

=item *

a C<bcvi> 'listener' process had been launched by Sally's X session startup
scripts

=item *

the 'ssh' command used to connect to 'pluto' was actually a shell alias that
set up the environment and invoked the real ssh command with additional
parameters for port forwarding the 'back channel'

=item *

Sally's login script on 'pluto' invoked C<bcvi> to unpack the environment and
set up the required authentication key

=item *

the 'vi' command used to edit the file on pluto was actually a shell alias
that invoked C<bcvi> to pass a message over the backchannel to the listener
process on Sally's workstation

=item *

the listener process unpacked the message to extract the hostname and filename
information needed to launch this command:

  gvim scp://pluto//home/sally/.bashrc

=back

For more information on setting up the listener and aliases, see
L<"INSTALLATION"> below.

=head2 Example 2

Our friend Sally is logged on to the server 'pluto' and is trying to configure
the 'Acme CRM' package.  She explores the filesystem and locates a useful file
in the documentation directory:

  sally@pluto:~$ cd /usr/share/doc/acmecrm/
  sally@pluto:acmecrm$ ls
  changelog.Debian.gz  copyright    README
  changelog.gz         manual.pdf   README.Debian
  sally@pluto:acmecrm$ bcp manual.pdf

In the final command above, Sally used the C<bcp> command to copy the PDF file
back to the desktop on her workstation.  Then she was able to simply
double-click the desktop icon to open it in her PDF viewer.

=head2 How Example 2 Worked

This second example used all the same infrastructure as the first (listener
process, shell aliases and port forward) but added the command C<bcp>.  Once
again, this is a shell alias that invokes C<bcvi> to send a message back to the
listener process.  The only difference is that this time the message instructs
the listener process to run this command:

  scp -q pluto:/usr/share/doc/acmecrm/manual.pdf /home/sally/Desktop

Note, for security reasons, the C<bcvi> process running on pluto is not allowed
to specify the command that gets executed on the workstation.  It simply sends
a request which includes hostname and filename details.  The listener process
determines which types of requests it will accept and which commands it will
run to handle them.

=head2 Example 3

Sally is now making progress setting up the Acme CRM package.  The next step is
to restore a database dump.  This will take some time and Sally has other
things to get on with so she kicks off this command (actually, two commands
separated by a semicolon):

  sally@pluto:~$ pg_restore -d acmecrm crm.pgdump; bnotify 'DB is restored!'

Sally then minimises her shell/ssh window and gets on with some other important
work.  Some minutes later, a desktop notification window pops up on her screen:

  +-------------------------+
  | Notification from pluto |
  | DB is restored!         |
  +-------------------------+

Sally can now return to her number one priority - completing the set up of the
Acme CRM software on pluto.

=head2 How Example 3 Worked

Once again, this example used all the same back channel infrastructure used by
the previous examples, but this one also used C<bcvi> plugins.

The C<bcvi> script itself requires no extra CPAN modules, but the interface to
the desktop notifications API requires the L<Desktop::Notify> module from CPAN.
It also requires a small 'plugin' module to provide the glue between the
listener process and the additional modules.  Plugins are described in more
detail in L<App::BCVI::Plugins>.

=head1 INSTALLATION

The C<bcvi> program is a standalone script with no companion modules and no
non-core dependencies.  To install it, simply copy the C<bin/bcvi> file from
the distribution to a directory in your search PATH.  Alternatively, you can
use the standard CPAN installation procedure to install the script to your
site bin directory:

    perl Makefile.PL
    make
    make test
    make install

The 'back channel' protocol requires a client and a server - the C<bcvi> script
performs both roles.  The server runs on your workstation and is typically
launched by adding a command to your X session startup.  For example under
Ubuntu/GNOME you might use the 'System' menu and select C<< Preferences >
Startup Applications >> and then use the 'Add' button to add this command:

    bcvi --listener

If you start a listener manually from a shell window you will want to append an
ampersand (C<< & >>) to put the command in the background.

When connecting to a server you will want to use this command to wrap the SSH
command and add the required port forwarding options:

    bcvi --wrap-ssh -- hostname

It is probably more convenient to set up an alias so that this happens on every
SSH connection.  Use this command to add the appropriate aliases to your bash
startup scripts:

    bcvi --add-aliases

Now that you have the server set up and ssh connection wrapping in place, you
need to install C<bcvi> on the machine you will ssh to:

    bcvi --install HOSTNAME

At this point it should all work.  When you log in to the machine using SSH, a
number of shell aliases will be available to you:

=over 4

=item B<vi>

Invokes gvim on your workstation, passing it an scp://... URL of the file(s)
you wish to edit

=item B<suvi>

Same as above, but uses sudoedit so system files (requiring root access) can be
edited too

=item B<bcp>

Copies the named file back to your workstation desktop

=back

Note: you may like to try SSHMenu (L<http://sshmenu.sourceforge.net/>) which
can invoke the ssh wrapper automatically when connecting to servers.

=head1 TECHNICAL DETAILS

If you successfully followed the installation instructions above, you can
probably skip this section.

When the listener process starts, it generates a random authentication key
which is saved in the file: F<$HOME/.config/bcvi/listener_key>

The process id of the listener is saved in F<$HOME/.config/bcvi/listener_pid>.
If you start a new listener, it will automatically kill off the old one.

The listener process then opens a local TCP port (by default, your user ID,
with a 9 appended, but you can use C<--port> to override it), saves the port
number in F<$HOME/.config/bcvi/listener_port> and waits for incoming
connections.

When you initiate an SSH connection using the shell alias, a command like
this is generated:

  ssh -R 10569:localhost:10569 HOSTNAME

The first port number is the local port that the listener will accept
connections on.  The second port number is the port on the remote machine that
the C<bcvi> client will connect to and which SSH will forward back to the
listener.  You can override the second port number when you connect.  The first
port number will be read from the F<listener_port> file.

The remote host needs to know three things in order to use the back channel:

=over 4

=item *

The hostname/FQDN that the server is known by from the originating workstation's
perspective

=item *

The port number on the server that SSH will forward back to the listener

=item *

The random authentication key from the F<listener_key_file>

=back

The ssh wrapper command arranges for these pieces of information to be
forwarded to the remote host.  If you don't want to know how it does that then
please skip the rest of this paragraph.  WARNING: It's not pretty.  OK, so you
really want to know?  Don't say I didn't warn you.  SSH does not normally pass
environment variables from client to server unless you customise the ssh config
files on the client and the server.  However, SSH B<does> pass the TERM
variable.  So, C<bcvi> appends all the extra info to the end of the TERM
variable before invoking SSH.  This 'overstuffed' TERM variable then needs to
be unpacked by the user's shell startup script on the server.  If this is not
done, then your term variable will be wrong and you'll need to set it manually
before editing your .profile to fix it.

Unpacking the environment is achieved by running C<bcvi> with the C<<
--unpack-term >> option to generate a few lines of Bash script.  Those lines
then need to be eval'd in the shell.  The standard installation procedure
achieves this by adding this line to your shell startup script:

  test -n "$(which bcvi)" && eval "$(bcvi --unpack-term)"

This line assumes that C<bcvi> is in your path.  Normally C<bcvi> will be in
your C<$HOME/bin> directory and normally this will be in your $PATH, but it's
something to check if things go wrong.

The standard installation will also set up the shell aliases listed above,
notably C<vi>, C<suvi> and C<bcp>, however plugin modules can install
additional aliases.

When one of these aliases is invoked, C<bcvi> connects to the listener via the
port-forward and sends a request similar to this:

  Auth-Key: 90a5aa7b5d55159b92828d4ba955fe75
  Host-Alias: pluto
  Command: vi
  Content-Length: 20
  
  /home/sally/.bashrc

The wire protocol is intended to be UTF8 encoded with Content-Length specified
in bytes rather than characters.

=head1 SUPPORT

The C<bcvi> script includes built-in documentation which you can access with
this command:

  bcvi --help

The documentation displayed will be customised to describe all options and
commands available - including those provided by plugin modules.

This documentation and more details on plugins are available via:

    perldoc App::BCVI
    perldoc App::BCVI::Plugins

You can also refer to:

=over 4

=item * Source Repository

L<http://github.com/grantm/bcvi>

=item * RT: CPAN's request tracker (for bug reports)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-BCVI>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/App-BCVI>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/App-BCVI>

=item * Search CPAN

L<http://search.cpan.org/dist/App-BCVI>

=back


=head1 COPYRIGHT & LICENSE

Copyright 2007-2012 Grant McLean C<< <grantm at cpan.org> >>

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.


=cut

1;
