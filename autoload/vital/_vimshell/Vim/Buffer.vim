let s:save_cpo = &cpo
set cpo&vim

function! s:_vital_loaded(V)
  let s:V = a:V
  let s:P = s:V.import('Prelude')
endfunction

function! s:_vital_depends()
  return ['Prelude']
endfunction

function! s:is_cmdwin()
  return bufname('%') ==# '[Command Line]'
endfunction

function! s:open(buffer, opener)
  let save_wildignore = &wildignore
  let &wildignore = ''
  try
    if s:P.is_funcref(a:opener)
      let loaded = !bufloaded(a:buffer)
      call a:opener(a:buffer)
    elseif a:buffer is 0 || a:buffer is ''
      let loaded = 1
      silent execute a:opener
      enew
    else
      let loaded = !bufloaded(a:buffer)
      if s:P.is_string(a:buffer)
        execute a:opener '`=a:buffer`'
      elseif s:P.is_number(a:buffer)
        silent execute a:opener
        execute a:buffer 'buffer'
      else
        throw 'vital: Vim.Buffer: Unknown opener type.'
      endif
    endif
  finally
    let &wildignore = save_wildignore
  endtry
  return loaded
endfunction

" Get selected text in visual mode.
function! s:get_selected_text()
    let save_z = getreg('z', 1)
    let save_z_type = getregtype('z')

    try
        normal! gv"zy
        return @z
    finally
        call setreg('z', save_z, save_z_type)
    endtry
endfunction


let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set et ts=2 sts=2 sw=2 tw=0:
