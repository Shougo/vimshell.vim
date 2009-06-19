"=============================================================================
" FILE: h.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 01 Apr 2009
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

function! vimshell#internal#h#execute(program, args, fd, other_info)
    " Execute from history.
    if get(g:vimshell#hist_buffer, 0) =~ '^h\s' || get(g:vimshell#hist_buffer, 0) == 'h'
        " Delete from history.
        call remove(g:vimshell#hist_buffer, 0)
    endif

    if empty(a:args)
        let l:num = 0
    else
        let l:num = str2nr(a:args[0])
    endif

    if len(g:vimshell#hist_buffer) > l:num
        if !empty(a:args[1:])
            " Join arguments.
            let l:line = g:vimshell#hist_buffer[l:num] . ' ' . join(a:args[1:], ' ')
        else
            let l:line = g:vimshell#hist_buffer[l:num]
        endif

        if a:other_info.has_head_spaces
            " Don't append history.
            call setline(line('.'), printf('%s %s', g:VimShell_Prompt, l:line))
        else
            call setline(line('.'), g:VimShell_Prompt . l:line)
        endif

        call vimshell#process_enter()
        return 1
    else
        " Error.
        call vimshell#error_line(a:fd, 'Not found in history.')
        return 0
    endif
endfunction
