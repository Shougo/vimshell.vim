"=============================================================================
" FILE: git.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>(Modified)
" Last Modified: 25 Dec 2009
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
    return s:get_git_dir() != ''
endfunction"}}}

function! vimshell#vcs#git#vcs_name()"{{{
    return 'git'
endfunction"}}}

function! vimshell#vcs#git#current_branch()"{{{
    let l:git_dir = s:get_git_dir()
    if !filereadable(l:git_dir . '/HEAD')
        return ''
    endif
    
    let l:lines = readfile(l:git_dir . '/HEAD')
    if empty(l:lines)
        return ''
    else
        return matchstr(l:lines[0], 'refs/heads/\zs.\+$')
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
    "l:status = vimshell#system('git status')
    return ''
endfunction"}}}

function! s:get_git_dir()"{{{
    let l:git_dir = finddir('.git', '.;')
    if l:git_dir != ''
        let l:git_dir = fnamemodify(l:git_dir, ':p')
    endif

    return l:git_dir
endfunction"}}}

" vim: foldmethod=marker
