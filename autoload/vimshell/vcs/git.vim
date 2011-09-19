"=============================================================================
" FILE: git.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 23 Jul 2010
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

" Check vcs directiory.
function! vimshell#vcs#git#is_vcs_dir()"{{{
  if getcwd() =~ '[\\/]\.git\%([\\/].*\)\?$'
    " Ignore inside .git directiory.
    return 0
  else
    return s:get_git_dir() != ''
  endif
endfunction"}}}

function! vimshell#vcs#git#vcs_name()"{{{
  return 'git'
endfunction"}}}

function! vimshell#vcs#git#current_branch()"{{{
  let git_dir = s:get_git_dir()
  if !filereadable(git_dir . '/HEAD')
    return ''
  endif

  let lines = readfile(git_dir . '/HEAD')
  if empty(lines)
    return ''
  else
    return matchstr(lines[0], 'refs/heads/\zs.\+$')
  endif
endfunction"}}}

function! vimshell#vcs#git#repository_name()"{{{
  return fnamemodify(vimshell#vcs#git#repository_root_path(), ':t')
endfunction"}}}

function! vimshell#vcs#git#repository_root_path()"{{{
  return s:get_git_dir()[: -(2+len('/.git'))]
endfunction"}}}

function! vimshell#vcs#git#repository_relative_path()"{{{
  return fnamemodify(getcwd(), ':p')[len(vimshell#vcs#git#repository_root_path())+1 : -2]
endfunction"}}}

function! vimshell#vcs#git#action_message()"{{{
  let action = []
  let current_action = ''
  let files = []
  for status in split(vimshell#system('git status', '', 500), '\n')
    if status =~# '^\s*#\s*unmerged'
      if current_action != '' && len(files) > 0
        call add(action, printf('%s:%d', current_action, len(files)))
      endif
      
      let current_action = 'unmerged'
    elseif status =~# '^\s*#\s*Untracked'
      if current_action != '' && len(files) > 0
        call add(action, printf('%s:%d', current_action, len(files)))
      endif
      
      let current_action = 'untracked'
    elseif status =~# '^#\t'
      let file = matchstr(status, '^#\t\zs.*')
      
      if file !=# '.gitignore' && file !~# '^modified:' 
        call add(files, file)
      endif
    endif
  endfor
  if current_action != '' && len(files) > 0
    call add(action, printf('%s:%d', current_action, len(files)))
  endif

  return join(action)
endfunction"}}}

function! s:get_git_dir()"{{{
  let git_dir = finddir('.git', ';')
  if git_dir != ''
    let git_dir = fnamemodify(git_dir, ':p')
  endif

  return git_dir
endfunction"}}}

" vim: foldmethod=marker
