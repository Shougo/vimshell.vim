"=============================================================================
" FILE: one.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>(Modified)
" Last Modified: 15 Feb 2009
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
" Version: 1.2, for Vim 7.0
"-----------------------------------------------------------------------------
" ChangeLog: "{{{
"   1.2:
"     - Use vimshell#error_line.
"   1.1:
"     - Supported grep.
"     - Fixed error on Unix.
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

function! vimshell#internal#one#execute(line, program, arguments, is_interactive, has_head_spaces, other_info)
    " Convert oneliner command.
    if has('win32') || has('win64')
        let l:arguments = split(a:arguments)
        let l:program = l:arguments[0]

        if l:program =~ '\a*awk$' || l:program == 'sed' || l:program =~ '\a*grep$'
            " AWK and sed.
            call s:execute_oneliner(l:program, join(l:arguments[1:]), "'.*'", '-f')
        elseif l:program == 'python'
            " Python.
            call s:execute_oneliner(l:program, join(l:arguments[1:]), "-c '.*'", '')
        elseif l:program == 'ruby' || l:program == 'perl'
            " Perl and Ruby.
            call s:execute_oneliner(l:program, join(l:arguments[1:]), "-e '.*'", '')
        else
            " Error.
            call vimshell#error_line(printf('Not found one liner command settings "%s".', l:program))
        endif
    else
        " This command is Windows only.
        execute printf('silent read! %s', a:arguments)
    endif
endfunction

function! s:execute_oneliner(program, arguments, liner_option, file_option)
    let l:liner = matchstr(a:arguments, a:liner_option)

    if empty(l:liner)
        execute printf('silent read! %s %s', a:program, a:arguments)
        return
    endif

    let l:forward = match(a:arguments, a:liner_option)
    let l:forward_args = (l:forward == 0)?  '' : a:arguments[: l:forward-1]
    let l:backward_args = a:arguments[matchend(a:arguments, a:liner_option) :]

    let l:tmpfile = tempname()
    call writefile([l:liner[match(a:liner_option, "'")+1 : -2]], l:tmpfile)

    execute printf('silent read! %s %s %s %s %s', a:program, l:forward_args, a:file_option, l:tmpfile, l:backward_args)

    call delete(l:tmpfile)
endfunction
