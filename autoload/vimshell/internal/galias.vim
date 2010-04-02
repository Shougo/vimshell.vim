"=============================================================================
" FILE: galias.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>(Modified)
" Last Modified: 02 Apr 2010
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
"=============================================================================

function! vimshell#internal#galias#execute(program, args, fd, other_info)
    if empty(a:args)
        " View all global aliases.
        for alias in keys(b:vimshell.galias_table)
            call vimshell#print_line(a:fd, printf('%s=%s', alias, b:vimshell.alias_table[alias]))
        endfor
    elseif join(a:args) =~ '^\h\w*$'
        if has_key(b:vimshell.galias_table, a:args[0])
            " View global alias.
            call vimshell#print_line(a:fd, b:vimshell.galias_table[a:args[0]])
        endif
    else
        " Define global alias.
        let l:args = join(a:args)

        if l:args !~ '^\h\w*\s*=\s*'
            call vimshell#error_line(a:fd, 'Wrong syntax.')
            return
        endif
        let l:expression = l:args[matchend(l:args, '^\h\w*\s*=\s*') :]
        execute 'let ' . printf("b:vimshell.galias_table['%s'] = '%s'", matchstr(l:args, '^\h\w*'),  substitute(l:expression, "'", "''", 'g'))
    endif
endfunction
