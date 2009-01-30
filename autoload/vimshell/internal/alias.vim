"=============================================================================
" FILE: alias.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>(Modified)
" Last Modified: 26 Jan 2009
" Usage: Just source this file.
"        source vimshell.vim
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
"     - Changed s:alias_table into b:vimshell_alias_table.
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

function! vimshell#internal#alias#execute(line, program, arguments, is_interactive, has_head_spaces, other_info)
    if a:arguments =~ '^\h\w*'
        let l:pos = matchend(a:arguments, '^\h\w*=')
        if l:pos > 0
            " Define alias.
            let b:vimshell_alias_table[a:arguments[:l:pos-2]] = a:arguments[l:pos :]
        elseif has_key(b:vimshell_alias_table, a:arguments[:l:pos])
            " View alias.
            call append(line('.'), b:vimshell_alias_table[a:arguments[:l:pos]])
            normal! j
        endif
    else
        " View all aliases.
        for alias in keys(b:vimshell_alias_table)
            call append(line('.'), printf('%s=%s', alias, b:vimshell_alias_table[alias]))
            normal! j
        endfor
    endif
endfunction
