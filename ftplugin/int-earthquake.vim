let s:save_cpo = &cpo
set cpo&vim

if exists('b:undo_ftplugin')
  let b:undo_ftplugin .= ' | '
else
  let b:undo_ftplugin = ''
endif

setlocal iskeyword+=$,#

" Search recent.
nmap <buffer> K <Plug>(int_earthquake_search_recent)

nnoremap <silent><buffer> <Plug>(int_earthquake_search_recent)
      \ :<C-u>call <SID>search_recent()<CR>

function! s:search_recent()"{{{
  " Set prompt line.
  let cur_text = expand('<cword>')
  if cur_text =~ '^#'
    let cur_text = ':search ' . cur_text
  elseif cur_text !~ '^\$'
    let cur_text = ':recent ' . cur_text
  endif
  call setline(line('$'), vimshell#interactive#get_prompt(line('$')) . cur_text)
  $
endfunction"}}}

let &cpo = s:save_cpo
