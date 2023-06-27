if exists('g:loaded_copilot')
  finish
endif
let g:loaded_copilot = 1

scriptencoding utf-8

command! -bang -nargs=? -range=-1 -complete=customlist,copilot#CommandComplete Copilot exe copilot#Command(<line1>, <count>, +"<range>", <bang>0, "<mods>", <q-args>)

if v:version < 800 || !exists('##CompleteChanged')
  finish
endif

function! s:ColorScheme() abort
  if &t_Co == 256
    hi def CopilotSuggestion guifg=#808080 ctermfg=244
  else
    hi def CopilotSuggestion guifg=#808080 ctermfg=8
  endif
  hi def link CopilotAnnotation Normal
endfunction

function! s:MapTab() abort
  if get(g:, 'copilot_no_tab_map') || get(g:, 'copilot_no_maps')
    return
  endif
  let tab_map = maparg('<Tab>', 'i', 0, 1)
  if !has_key(tab_map, 'rhs')
    imap <script><silent><nowait><expr> <Tab> copilot#Accept()
  elseif tab_map.rhs !~# 'copilot'
    if tab_map.expr
      let tab_fallback = '{ -> ' . tab_map.rhs . ' }'
    else
      let tab_fallback = substitute(json_encode(tab_map.rhs), '<', '\\<', 'g')
    endif
    let tab_fallback = substitute(tab_fallback, '<SID>', '<SNR>' . get(tab_map, 'sid') . '_', 'g')
    if get(tab_map, 'noremap') || get(tab_map, 'script') || mapcheck('<Left>', 'i') || mapcheck('<Del>', 'i')
      exe 'imap <script><silent><nowait><expr> <Tab> copilot#Accept(' . tab_fallback . ')'
    else
      exe 'imap <silent><nowait><expr>         <Tab> copilot#Accept(' . tab_fallback . ')'
    endif
  endif
endfunction

function! s:Event(type) abort
  try
    call call('copilot#On' . a:type, [])
  catch
    call copilot#logger#Exception()
  endtry
endfunction

" check if file size greater than copilot_max_file_size
function! s:start_action(type) abort
  let l:disabled = get(b:, 'copilot_max_file_size_disabled', -1)
  if l:disabled == 1
    return
  endif
  if l:disabled == -1
    if getfsize(expand('<afile>')) > get(g:, 'copilot_max_file_size', 1024*1024)
      let b:copilot_max_file_size_disabled = 1
      return
    else
      let b:copilot_max_file_size_disabled = 0
    endif
  endif
  call s:Event(a:type)
endfunction

augroup github_copilot
  autocmd!
  autocmd InsertLeave          * call s:start_action('InsertLeave')
  autocmd BufLeave             * if mode() =~# '^[iR]'|call s:start_action('InsertLeave')|endif
  autocmd InsertEnter          * call s:start_action('InsertEnter')
  autocmd BufEnter             * if mode() =~# '^[iR]'|call s:start_action('InsertEnter')|endif
  autocmd CursorMovedI         * call s:start_action('CursorMovedI')
  autocmd CompleteChanged      * call s:start_action('CompleteChanged')
  autocmd ColorScheme,VimEnter * call s:ColorScheme()
  autocmd VimEnter             * call s:MapTab()
  autocmd BufReadCmd copilot://* setlocal buftype=nofile bufhidden=wipe nobuflisted readonly nomodifiable
augroup END

call s:ColorScheme()
call s:MapTab()
if !get(g:, 'copilot_no_maps')
  imap <Plug>(copilot-dismiss)     <Cmd>call copilot#Dismiss()<CR>
  if empty(mapcheck('<C-]>', 'i'))
    imap <silent><script><nowait><expr> <C-]> copilot#Dismiss() . "\<C-]>"
  endif
  imap <Plug>(copilot-next)     <Cmd>call copilot#Next()<CR>
  imap <Plug>(copilot-previous) <Cmd>call copilot#Previous()<CR>
  imap <Plug>(copilot-suggest)  <Cmd>call copilot#Suggest()<CR>
  try
    if !has('nvim') && &encoding ==# 'utf-8'
      " avoid 8-bit meta collision with UTF-8 characters
      let s:restore_encoding = 1
      set encoding=cp949
    endif
    if empty(mapcheck('<M-]>', 'i'))
      imap <M-]> <Plug>(copilot-next)
    endif
    if empty(mapcheck('<M-[>', 'i'))
      imap <M-[> <Plug>(copilot-previous)
    endif
    if empty(mapcheck('<M-Bslash>', 'i'))
      imap <M-Bslash> <Plug>(copilot-suggest)
    endif
  finally
    if exists('s:restore_encoding')
      set encoding=utf-8
    endif
  endtry
endif

call copilot#Init()

let s:dir = expand('<sfile>:h:h')
if getftime(s:dir . '/doc/copilot.txt') > getftime(s:dir . '/doc/tags')
  silent! execute 'helptags' fnameescape(s:dir . '/doc')
endif
