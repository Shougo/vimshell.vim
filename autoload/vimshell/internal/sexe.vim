"=============================================================================
" FILE: sexe.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 03 Sep 2009
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
" Version: 1.1, for Vim 7.0
"-----------------------------------------------------------------------------
" ChangeLog: "{{{
"   1.1: 
"     - Shell escape.
"     - Improved in Windows.
"
"   1.0: Initial version.
""}}}
"-----------------------------------------------------------------------------
" TODO: "{{{
"     - Nothing.
""}}}
" Bugs"{{{
"     -
""}}}
"=============================================================================

function! vimshell#internal#sexe#execute(program, args, fd, other_info)"{{{
    " Execute shell command.
    let l:iswin = has('win32') || has('win64')
    let l:cmdline = ''
    for arg in a:args
        if l:iswin
            let l:arg = substitute(arg, '"', '\\"', 'g')
            let l:arg = substitute(arg, '[<>|^]', '^\0', 'g')
            let l:cmdline .= '"' . arg . '" '
        else
            let l:cmdline .= shellescape(arg) . ' '
        endif
    endfor

    if l:iswin
        let l:cmdline = '"' . l:cmdline . '"'
    endif

    " Set redirection.
    if a:fd.stdin == ''
        let l:stdin = ''
    elseif a:fd.stdin == '/dev/null'
        let l:null = tempname()
        call writefile([], l:null)

        let l:stdin = '<' . l:null
    else
        let l:stdin = '<' . a:fd.stdin
    endif

    echo 'Running command.'
    let l:result = system(printf('%s %s', l:cmdline, l:stdin))
    call vimshell#print(a:fd, l:result)
    redraw
    echo ''

    if a:fd.stdin == '/dev/null'
        call delete(l:null)
    endif

    let b:vimshell_system_variables['status'] = v:shell_error

    return 0
endfunction"}}}

