let s:save_cpo = &cpo
set cpo&vim

scriptencoding utf-8

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

function! s:search_recent() "{{{
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

" For echodoc. "{{{
let s:doc_dict = {
      \ 'name' : 'earthquake.gem',
      \ 'rank' : 10,
      \ 'filetypes' : { 'int-earthquake' : 1 },
      \ }
let s:doc_table = {
      \ ':delete' : 'Delete :delete $xx',
      \ ':retweet' : 'Retweet :retweet $xx',
      \ ':recent' : 'Timeline :recent [jugyo] | List :recent yugui/ruby-committers',
      \ ':search' : 'Search :search #ruby',
      \ ':eval' : 'Eval :eval Time.now',
      \ ':exit' : 'Exit :exit',
      \ ':reconnect' : 'Reconnect :reconnect',
      \ ':restart' : 'Restart :restart',
      \ ':thread' : 'Threads :thread $xx',
      \ ':plugin_install' : 'Install Plugins :plugin_install https://gist.github.com/899506',
      \ ':alias' : 'Alias :alias :rt :retweet',
      \ ':update' : 'Tweet Ascii Art :update<ENTER>',
      \ ':filter' : 'Stream Filter Tracking :filter keyword earthquakegem twitter | user jugyo matsuu | off',
      \ }
function! s:doc_dict.search(cur_text) "{{{
  " Get command name.
  let command = matchstr(a:cur_text, '^⚡ \zs:\h\w*\ze')
  if command == '' || !has_key(s:doc_table, command)
    return []
  endif

  let description = s:doc_table[command]

  let usage = [
        \ { 'text' : command, 'highlight' : 'Statement' },
        \ { 'text' : ' ' . description },
        \ ]

  return usage
endfunction"}}}

if exists('g:loaded_echodoc') && g:loaded_echodoc
  call echodoc#register('earthquake.gem', s:doc_dict)
endif
"}}}

let &cpo = s:save_cpo
