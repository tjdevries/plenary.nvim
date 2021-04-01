" Set up neorocks if it is installed.
lua pcall(function() require('plenary.neorocks').setup_paths() end)

" Create command for running busted
command! -nargs=1 -complete=file PlenaryBustedFile
      \ lua require('plenary.busted').run(vim.fn.expand("<args>"))

command! -nargs=+ -complete=file PlenaryBustedDirectory
      \ lua require('plenary.test_harness').test_directory_command(vim.fn.expand("<args>"))

function! s:write_and_run_testfile() abort
    if &filetype == 'lua'
        :write
        :lua require('plenary.test_harness').test_directory(vim.fn.expand("%:p"))
    endif
    return
endfunction

nnoremap <Plug>PlenaryWriteAndRunTestFile :call <sid>write_and_run_testfile()<CR>
nnoremap <Plug>PlenaryTestFile :lua require('plenary.test_harness').test_directory(vim.fn.expand("%:p"))<CR>
