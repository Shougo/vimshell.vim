let s:save_cpo = &cpo
set cpo&vim

function! s:is_cmdwin()
  return bufname('%') ==# '[Command Line]'
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set et ts=2 sts=2 sw=2 tw=0:
