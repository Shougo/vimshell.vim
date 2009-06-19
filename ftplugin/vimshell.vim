" Key mappings.
nmap <buffer><silent> <CR> <Plug>(vimshell_enter)
imap <buffer><silent> <CR> <ESC><CR>
nnoremap <buffer><silent> q :<C-u>hide<CR>
inoremap <buffer> <C-j> <C-x><C-o><C-p>
imap <buffer> <C-p> <Plug>(vimshell_insert_command_completion)
imap <buffer> <C-z> <Plug>(vimshell_push_current_line)
nmap <buffer> <C-p> <Plug>(vimshell_previous_prompt)
nmap <buffer> <C-n> <Plug>(vimshell_next_prompt)
nmap <buffer> <C-d> <Plug>(vimshell_delete_previous_prompt)

" Filename completion.
inoremap <buffer><expr><TAB>  pumvisible() ? "\<C-n>" : exists(':NeoComplCacheDisable') && exists('*neocomplcache#manual_filename_complete') ? 
            \ neocomplcache#manual_filename_complete() : "\<C-x>\<C-f>"

