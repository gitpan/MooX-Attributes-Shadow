# --8<--8<--8<--8<--
#
# Copyright (C) 2012 Smithsonian Astrophysical Observatory
#
# This file is part of MooX-Attributes-Shadow
#
# MooX-Attributes-Shadow is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or (at
# your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# -->8-->8-->8-->8--

package MooX::Attributes::Shadow::Role;

use strict;

use Moo::Role;

use MooX::Attributes::Shadow ':all';

## no critic (ProhibitSubroutinePrototypes)
sub shadowable_attrs (@) {

    my $attrs = [ @_ ];
    my $from = caller;

    ## no critic (ProhibitNoStrict)
    no strict 'refs';

    *{ caller . '::_shadowable_attrs'} = sub { @{$attrs} };

    return;
}


1;


__END__

=head1 NAME

MooX::Attributes::Shadow::Role - enumerate shadowable attributes in a contained class

=head1 SYNOPSIS

  # in the contained class
  package Foo;
  use Moo;
  with 'MooX::Attributes::Shadow::Role';

  shadowable_attrs 'x', 'y';

  has x => ( is => 'ro' );
  has y => ( is => 'ro' );


  # in the container class

  package Bar;

  use Moo;
  use Foo;

  # create accessors with a prefix to avoid collisions; no need to
  # specify which ones
  Foo->shadow_attrs( fmt => sub { 'pfx_' . shift } );

  # later in the code, use the attributes when creating a new Foo
  # object.

  sub create_foo {
    my $self = shift;
    my $foo = Foo->new( Foo->xtract_attrs( $self ) );
  }


=head1 DESCRIPTION

B<MooX::Attributes::Shadow::Role> provides a means for a class to
identify attributes which should be shadowed to classes which contain
it.  (See B<MooX::Attributes::Shadow> for more on what this means).
A class containing a class composed with this role need know nothing about
the attributes which will be shadowed, and can use the class methods to
integrate the shadowable attributes into their interface.


=head1 INTERFACE

=head2 Contained class functions

=over

=item B<shadowable_attrs>

  shadowable_attrs @attrs;

This is called by the contained class to identify which attributes are
available for shadowing.  It does B<not> create them, it merely
records them.

=back


=head2 Class methods for use by the Container Classes

=over

=item B<shadow_attrs>

   ContainedClass->shadow_attrs( %options );

This method creates attributes shadowing the I<ContainedClass>'s
shadowable attributes in the class which calls it.  The attributes are
created as read-only.  There is no means of specifying additional
attribute options.

It takes the following options:

=over

=item fmt

This is a reference to a subroutine which should return a modified
attribute name (e.g. to prevent attribute collisions).  It is passed
the attribute name as its first parameters.

=item attrs

This is a list of attributes to shadow; this overrides the list
provided by the contained class in the call to B<shadowable_attrs>.

=back

=item B<xtract_attrs>

  %shadowed_attrs = ContainedClass->xtract_attrs( $obj );

This is extracts the shadowed attributes from an object instantiated
from the containing class.

=back

=head1 COPYRIGHT & LICENSE

Copyright 2012 Smithsonian Astrophysical Observatory

This software is released under the GNU General Public License.  You
may find a copy at

   http://www.fsf.org/copyleft/gpl.html


=head1 AUTHOR

Diab Jerius E<lt>djerius@cfa.harvard.eduE<gt>
