"=============================================================================
" FILE: complete.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 22 Oct 2009
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

function! vimshell#complete#history_complete_whole()"{{{
    let &iminsert = 0
    let &imsearch = 0

    " Command completion.

    " Set complete function.
    let &l:omnifunc = 'vimshell#complete#history_complete#omnifunc_whole'

    if exists(':NeoComplCacheDisable') && exists('*neocomplcache#manual_omni_complete')
        return neocomplcache#manual_omni_complete()
    else
        return "\<C-x>\<C-o>\<C-p>"
    endif
endfunction"}}}
function! vimshell#complete#history_complete_insert()"{{{
    let &iminsert = 0
    let &imsearch = 0

    " Command completion.

    " Set complete function.
    let &l:omnifunc = 'vimshell#complete#history_complete#omnifunc_insert'

    if exists(':NeoComplCacheDisable') && exists('*neocomplcache#manual_omni_complete')
        return neocomplcache#manual_omni_complete()
    else
        return "\<C-x>\<C-o>\<C-p>"
    endif
endfunction"}}}
function! vimshell#complete#command_complete()"{{{
    let &iminsert = 0
    let &imsearch = 0

    let l:cur_text = (col('.') < 2)? '' : getline('.')[: col('.')-2]
    let l:cur_text = substitute(l:cur_text, '^' . g:VimShell_Prompt . '\s*', '', '')
    if l:cur_text =~ '^.\+/\|^[^\\]\+\s'
        " Filename completion.
        if exists(':NeoComplCacheDisable') && exists('*neocomplcache#manual_filename_complete')
            return neocomplcache#manual_filename_complete()
        else
            return "\<C-x>\<C-f>"
        endif
    endif

    " Command completion.

    " Set complete function.
    let &l:omnifunc = 'vimshell#complete#command_complete#omnifunc'

    if exists(':NeoComplCacheDisable') && exists('*neocomplcache#manual_omni_complete')
        return neocomplcache#manual_omni_complete()
    else
        return "\<C-x>\<C-o>\<C-p>"
    endif
endfunction"}}}

" vim: foldmethod=marker
