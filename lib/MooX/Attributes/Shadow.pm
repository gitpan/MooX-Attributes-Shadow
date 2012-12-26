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

package MooX::Attributes::Shadow;

use strict;
use warnings;

our $VERSION = '0.02';

use Carp;
use Params::Check qw[ check last_error ];
use Scalar::Util qw[ blessed ];

use Exporter 'import';

our %EXPORT_TAGS = ( all => [ qw( shadow_attrs shadowed_attrs xtract_attrs ) ],
		   );
Exporter::export_ok_tags('all');

my %MAP;

## no critic (ProhibitAccessOfPrivateData)

sub shadow_attrs {

    my $contained = shift;

    my $container = caller;

    my $args = check( {
            fmt => {
                allow => sub { ref $_[0] eq 'CODE' }
            },
            attrs => { allow => sub { ref $_[0] eq 'ARRAY' && @{ $_[0] } }, },
            private  => { default => 1 },
            instance => {},
        },
        {@_} ) or croak( "error parsing arguments: ", last_error, "\n" );


    unless ( exists $args->{attrs} ) {

        $args->{attrs} = [ eval { $contained->shadowable_attrs } ];

        croak( "must specify attrs or call shadowable_attrs in shadowed class" )
          if $@;

    }

    my $has = $container->can( 'has' )
      or croak( "container class $container does not have a 'has' function.  Is it really a Moo class?" );

    my %map;
    for my $attr ( @{ $args->{attrs} } ) {

        my $alias = $args->{fmt}     ? $args->{fmt}->( $attr )    : $attr;
        my $priv  = $args->{private} ? "_shadow_${contained}_${alias}" : $alias;
        $priv =~ s/::/_/g;
        $map{$attr} = { priv => $priv, alias => $alias };

        ## no critic (ProhibitNoStrict)
        no strict 'refs';
        $has->(
            $priv => (
                is        => 'ro',
                init_arg  => $alias,
                predicate => "_has_${priv}",
            ) );

    }

    if ( defined $args->{instance} ) {

        $MAP{$contained}{$container}{instance}{ $args->{instance} } = \%map;

    }

    else {

        $MAP{$contained}{$container}{default} = \%map;

    }

    return;
}

sub _resolve_attr_env {

    my ( $contained, $container, $options ) = @_;

    # contained should be resolved into a class name
    my $containedClass = blessed $contained || $contained;

    # allow $container to be either a class or an object
    my $containerClass = blessed $container || $container;

    my $map = defined $options->{instance}
            ? $MAP{$containedClass}{$containerClass}{instance}{$options->{instance}}
	    : $MAP{$containedClass}{$containerClass}{default};

    croak( "attributes must first be shadowed using ${containedClass}::shadow_attrs\n" )
      unless defined $map;

    return $map;
}

# call as
# shadowed_attrs( $ContainedClass, [ $container ], \%options)

sub shadowed_attrs {

    my $containedClass = shift;
    my $options = 'HASH' eq ref $_[-1] ? pop() : {};

    my $containerClass = @_ ? shift : caller();

    my $map = _resolve_attr_env( $containedClass, $containerClass, $options );

    return { map { $map->{$_}{alias}, $_ } keys %$map }
}

# call as
# xtract_attrs( $ContainedClass, $container_obj, \%options)
sub xtract_attrs {

    my $containedClass = shift;
    my $options = 'HASH' eq ref $_[-1] ? pop() : {};
    my $container = shift;
    my $containerClass = blessed $container or
      croak( "container_obj parameter is not a container object\n" );

    my $map = _resolve_attr_env( $containedClass, $containerClass, $options );

    my %attr;
    while( my ($attr, $names) = each %$map ) {

	my $priv = $names->{priv};
	my $has = "_has_${priv}";

	$attr{$attr} = $container->$priv
	  if $container->$has;
    }

    return %attr;
}

1;
__END__

=head1 NAME

MooX::Attributes::Shadow - shadow attributes of contained objects

=head1 SYNOPSIS

  # shadow Foo's attributes in Bar
  package Bar;

  use Moo;
  use Foo;

  use MooX::Attributes::Shadow ':all';

  # create attributes shadowing class Foo's a and b attributes, with a
  # prefix to avoid collisions.
  shadow_attrs( Foo =>
                attrs => [ qw( a b ) ],
                fmt => sub { 'pfx_' . shift },
              );

  # create an attribute which holds the contained oject, and
  # delegate the shadowed accessors to it.
  has foo   => ( is => 'ro',
                 lazy => 1,
                 default => sub { Foo->new( xtract_attrs( Foo => shift ) ) },
                 handles => shadowed_attrs( Foo ),
               );


=head1 DESCRIPTION

Classes which contain other objects at times need to
reflect the contained objects' attributes in their own attributes.

In most cases, simple method delegation will suffice:

  package ContainsFoo;

  has foo => ( is => 'ro',
               isa => sub { die unless eval { shift->isa('Foo') } },
               handles => [ 'a' ],
             );

However, method delegation does not kick in when attributes are
specified during instantiation of the I<container> class.  For
example, in

  ContainsFoo->new( a => 1 );

the delegated method for C<a> is I<not> called, and C<a> is simply dropped.

One way of dealing with this is to establish proxy attributes which
shadow C<Foo>'s attributes, and delay passing them on until after
the container object has been instantiated:

  has _a => ( is => 'ro', init_arg => 'a' );

  sub BUILD {

     my $self = shift;

     $self->foo->a( $self->_a );

  }

This requires that C<Foo>'s C<a> attribute be of type C<rw>.  If the
C<foo> attribute can be constructed on the fly,

  has foo => ( is => 'ro',
               handles => [ 'a' ],
               lazy => 1,
               sub default { my $self = shift,
                             Foo->new( a => $self->_a ) }
             )

Then C<Foo>'s attribute can be of type C<ro>.

This is tedious when more than one attribute is propagated.  If the
container has its own I<a> attribute, then one must do more work to
avoid name space collisions.

B<MooX::Attributes::Shadow> provides a means of registering the
attributes to be shadowed, automatically creating proxy attributes in
the container class, and easily extracting the shadowed attributes and
values from the container class for use in the contained class's
constructor.

A contained class can use B<MooX::Attributes::Shadow::Role> to
simplify things even further, so that container classes using it need
not know the names of the attributes to shadow.

=head1 INTERFACE

=over

=item B<shadow_attrs>

   shadow_attrs( $contained_class, attrs => \@attrs, %options );

Create read-only attributes for the attributes in C<@attrs> and
associate them with C<$contained_class>.  There is no means of
specifying additional attribute options.

It takes the following options:

=over

=item fmt

This is a reference to a subroutine which should return a modified
attribute name (e.g. to prevent attribute collisions).  It is passed
the attribute name as its first parameter.

=item instance

In the case where more than one instance of an object is contained,
this (string) is used to identify an individual instance.

=item private

If true, the actual attribute name is mangled; the attribute
initialization name is left untouched (see the C<init_arg> option to
the B<Moo> C<has> subroutine).  This defaults to true.

=back

=item B<shadowed_attrs>

  $attrs = shadowed_attrs( $contained, [ $container,] \%options );

Return a hash of attributes shadowed from C<$contained> into
C<$container>.  C<$contained> and C<$container> may either be a class
name or an object. If C<$container> is not specified, the package name
of the calling routine is used.

It takes the following options:

=over

=item instance

In the case where more than one instance of an object is contained,
this (string) is used to identify an individual instance.

=back

The keys in the returned hash are the attribute initialization names
(not the mangled ones) in the I<container> class; the hash values are
the attribute names in the I<contained> class.  This makes it easy to
delegate accessors to the contained class:

  has foo   => ( is => 'ro',
                 lazy => 1,
                 default => sub { Foo->new( xtract_attrs( Foo => shift ) ) },
                 handles => shadowed_attrs( 'Foo' ),
               );


=item B<xtract_attrs>

  %attrs = xtract_attrs( $contained, $container_obj, \%options );

After the container class is instantiated, B<xtract_attrs> is used to
extract attributes for the contained object from the container object.
C<$contained> may be either a class name or an object in the contained
class.

It takes the following options:

=over

=item instance

In the case where more than one instance of an object is contained,
this (string) is used to identify an individual instance.

=back

=back



=head1 COPYRIGHT & LICENSE

Copyright 2012 Smithsonian Astrophysical Observatory

This software is released under the GNU General Public License.  You
may find a copy at

   http://www.fsf.org/copyleft/gpl.html


=head1 AUTHOR

Diab Jerius E<lt>djerius@cfa.harvard.eduE<gt>
