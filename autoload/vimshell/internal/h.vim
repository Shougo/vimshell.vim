"=============================================================================
" FILE: h.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 12 Sep 2009
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
"     - Use startinsert!.
"
"   1.2:
"     - Refactoringed.
"
"   1.1:
"     - Implemented "h string".
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

function! vimshell#internal#h#execute(program, args, fd, other_info)
    " Execute from history.

    " Delete from history.
    call vimshell#remove_history('h')

    if empty(a:args) || a:args[0] =~ '^\d\+'
        if empty(a:args)
            let l:num = 0
        else
            let l:num = str2nr(a:args[0])
        endif

        if l:num >= len(g:vimshell#hist_buffer)
            " Error.
            call vimshell#error_line(a:fd, 'Not found in history.')
            return 0
        endif

        let l:hist = g:vimshell#hist_buffer[l:num]
    else
        let l:args = '^' . escape(join(a:args), '~" \.^$[]*')
        for h in g:vimshell#hist_buffer
            if h =~ l:args
                let l:hist = h
                break
            endif
        endfor

        if !exists('l:hist')
            " Error.
            call vimshell#error_line(a:fd, 'Not found in history.')
            return 0
        endif
    endif

    if a:other_info.has_head_spaces
        " Don't append history.
        call setline(line('.'), printf('%s %s', g:VimShell_Prompt, l:hist))
    else
        call setline(line('.'), g:VimShell_Prompt . l:hist)
    endif

    try
        let l:skip_prompt = vimshell#parser#eval_script(l:hist, a:other_info)
    catch /.*/
        call vimshell#error_line({}, v:exception)
        call vimshell#print_prompt()
        call interactive#highlight_escape_sequence()

        call vimshell#start_insert()
        return
    endtry

    if l:skip_prompt
        " Skip prompt.
        return
    endif

    call interactive#highlight_escape_sequence()

    if a:other_info.is_interactive
        call vimshell#print_prompt()
        call vimshell#start_insert()
        startinsert!
    endif

    return 1
endfunction
