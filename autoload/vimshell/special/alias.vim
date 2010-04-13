"=============================================================================
" FILE: alias.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>(Modified)
" Last Modified: 13 Apr 2010
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
"=============================================================================

function! vimshell#special#alias#execute(program, args, fd, other_info)
  if empty(a:args)
    " View all aliases.
    for alias in keys(b:vimshell.alias_table)
      call vimshell#print_line(a:fd, printf('%s=%s', alias, b:vimshell.alias_table[alias]))
    endfor
  elseif join(a:args) =~ '^\h\w*$'
    if has_key(b:vimshell.alias_table, a:args[0])
      " View alias.
      call vimshell#print_line(a:fd, b:vimshell.alias_table[a:args[0]])
    endif
  else
    " Define alias.
    let l:args = join(a:args)

    " Parse command line.
    let l:alias_name = matchstr(l:args, '^\h\w*')

    " Next.
    let l:args = l:args[matchend(l:args, '^\h\w*') :]
    if l:alias_name == '' || l:args !~ '^\s*=\s*'
      throw 'Wrong syntax: ' . l:args
    endif

    " Skip =.
    let l:expression = l:args[matchend(l:args, '^\s*=\s*') :]

    try
      execute printf('let b:vimshell.alias_table[%s] = %s', string(l:alias_name),  string(l:expression))
    catch
      throw 'Wrong syntax: ' . l:args
    endtry
  endif
endfunction
