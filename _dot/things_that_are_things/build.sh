#! /bin/bash

function build {
    dss --style style.dss --input $1.dot | dot -Tsvg > ../../img/things_that_are_things/$1.svg
}

build overview
build not_functor
build functor_not_apply
build apply_not_applicative
build applicative_not_monad
build apply_not_flatmap
build flatmap_not_monad
