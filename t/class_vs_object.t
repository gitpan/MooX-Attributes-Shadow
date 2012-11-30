#!perl

use Test::More;

use lib 't';
use MooX::Attributes::Shadow ':all';

{
    package Foo;

    use Moo;

    use Contained;
    use MooX::Attributes::Shadow ':all';

    shadow_attrs( 'Contained', attrs => [ 'a', 'b' ], fmt => sub { 'x' . shift }  );

    has foo => (
        is      => 'ro',
        default => sub { Contained->new },
    );

}

my $bar = Foo->new( xa => 1, xb => 2 );
is_deeply( { xtract_attrs( Contained => $bar ) }, { a => 1, b => 2 }, 'extract: class' );
is_deeply( { xtract_attrs( $bar->foo => $bar ) }, { a => 1, b => 2 }, 'extract: object' );

is_deeply( shadowed_attrs( 'Contained', 'Foo' ) , { 'xa' => 'a', 'xb' => 'b' }, 'shadowed: class, class' );
is_deeply( shadowed_attrs( 'Contained', $bar )  , { 'xa' => 'a', 'xb' => 'b' }, 'shadowed: class, object' );
is_deeply( shadowed_attrs( $bar->foo, $bar )    , { 'xa' => 'a', 'xb' => 'b' }, 'shadowed: object, object' );

done_testing;
