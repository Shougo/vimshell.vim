"=============================================================================
" FILE: let.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>(Modified)
" Last Modified: 21 Jun 2009
" Usage: Just source this file.
" License: MIT license  {{{
"     Permission is hereby granted, free of charge, to any person obtaining
"     a copy of this software and associated documentation files (the
"     "Software"), to deal in the Software without restriction, including
"     without limitation the rights to use, copy, modify, merge, publish,
"     distribute, sublicense, and/or sell copies of the Software, and to
"     permit persons to whom the Software is furnished to do so, subject to
"     the following conditions:
"
"     The above copyright notice and this permission notice shall be included
"     in all copies or substantial portions of the Software.
"
"     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
"     OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
"     MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
"     IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
"     CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
"     TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
"     SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
" }}}
" Version: 1.3, for Vim 7.0
"-----------------------------------------------------------------------------
" ChangeLog: "{{{
"   1.3:
"     - Supported system variables.
"
"   1.2:
"     - Implemented special commands.
"
"   1.1:
"     - Optimized parse.
"
"   1.0:
"     - Initial version.
""}}}
"-----------------------------------------------------------------------------
" TODO: "{{{
"     - Nothing.
""}}}
" Bugs"{{{
"     -
""}}}
"=============================================================================

function! vimshell#special#let#execute(program, args, fd, other_info)
    let l:args = join(a:args)

    if l:args !~ '^$$\?\h\w*'
        call vimshell#error_line(a:fd, 'Wrong syntax.')
        return
    endif

    if l:args =~ '^$\zs\l\w*'
        " User variable.
        let l:varname = printf("b:vimshell_variables['%s']", matchstr(l:args, '^$\zs\l\w*'))
    elseif l:args =~ '^$\u\w*'
        " Environment variable.
        let l:varname = matchstr(l:args, '^$\u\w*')
    elseif l:args =~ '^$$\h\w*'
        " System variable.
        let l:varname = printf("b:vimshell_system_variables['%s']", matchstr(l:args, '^$$\zs\h\w*'))
    else
        let l:varname = ''
    endif

    let l:expression = l:args[match(l:args, '^$$\?\h\w*\zs') :]
    while l:expression =~ '$$\h\w*'
        let l:expression = substitute(l:expression, '$$\h\w*', printf("b:vimshell_system_variables['%s']", matchstr(l:expression, '$$\zs\h\w*')), '')
    endwhile
    while l:expression =~ '$\l\w*'
        let l:expression = substitute(l:expression, '$\l\w*', printf("b:vimshell_variables['%s']", matchstr(l:expression, '$\zs\l\w*')), '')
    endwhile

    execute 'let ' . l:varname . l:expression
endfunction
