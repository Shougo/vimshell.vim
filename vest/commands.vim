" Tests for vimshell.

scriptencoding utf-8

" Saving 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}

Context Vesting.run()
  It tests internal commands.
    VimShellCreate

    let $FOO = ''
    call vimshell#execute('export FOO=foo')
    ShouldEqual $FOO, 'foo'

    " It contains space
    let $FOO = ''
    call vimshell#execute('export FOO="foo bar"')
    ShouldEqual $FOO, 'foo bar'

    let $FOO = ''
    let $BAR = ''
    call vimshell#execute('export FOO="foo" BAR="bar"')
    ShouldEqual $FOO, 'foo'
    ShouldEqual $BAR, 'bar'

    " Error pattern
    let $FOO = ''
    let $BAR = ''
    call vimshell#execute('export FOO = "foo" BAR="bar"')
    ShouldEqual $FOO, ''
    ShouldEqual $BAR, ''

    VimShellCreate -toggle
  End
End

Fin

" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}

" vim:foldmethod=marker:fen:
