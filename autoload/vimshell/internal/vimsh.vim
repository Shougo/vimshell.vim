"=============================================================================
" FILE: vimsh.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 12 Jul 2009
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
"   1.2:
"     - Print all error.
"     - Improved error print format.
"
"   1.1:
"     - Improved parser.
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

function! vimshell#internal#vimsh#execute(program, args, fd, other_info)
    " Create new vimshell or execute script.
    if empty(a:args)
        call vimshell#print_prompt()
        call vimshell#create_shell(0)
        return 1
    else
        " Filename escape.
        let l:filename = join(a:args, ' ')

        if filereadable(l:filename)
            let l:scripts = readfile(l:filename)

            let l:other_info = { 'has_head_spaces' : 0, 'is_interactive' : 0, 'is_background' : 0 }
            let l:i = 0
            let l:skip_prompt = 0
            for l:script in l:scripts
                try
                    let l:skip_prompt = vimshell#parser#eval_script(l:script, l:other_info)
                catch /.*/
                    call vimshell#error_line({}, printf('%s(%d): %s', join(a:args, ' '), l:i, v:exception))
                    return 0
                endtry

                let l:i += 1
            endfor

            if l:skip_prompt
                " Skip prompt.
                return 1
            endif
        else
            " Error.
            call vimshell#error_line(a:fd, printf('Not found the script "%s".', l:filename))
        endif
    endif

    return 0
endfunction
