"=============================================================================
" FILE: vimsh.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 31 Mar 2009
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
" Version: 1.0, for Vim 7.0
"-----------------------------------------------------------------------------
" ChangeLog: "{{{
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
        let l:filename = escape(join(a:args, ' '), "\\*?[]{}`$%#&'\"|!<>+")

        if filereadable(l:filename)
            let l:scripts = readfile(l:filename)

            for script in l:scripts
                " Delete head spaces.
                let l:program = (empty(script))? '' : split(script)[0]
                let l:arguments = substitute(script, '^\s*' . l:program . '\s*', '', '')
                let l:fd = { 'stdin' : '', 'stdout' : '', 'stderr' : '' }
                let l:other_info = { 'has_head_spaces' : 0, 'is_interactive' : 0, 'is_background' : 0 }

                call vimshell#execute_command(l:program, split(l:arguments), l:fd, l:other_info)
                normal! j
            endfor
        else
            " Error.
            call vimshell#error_line(a:fd, printf('Not found the script "%s".', l:filename))
        endif
    endif

    return 0
endfunction
