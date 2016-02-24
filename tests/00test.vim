    map <Plug>DisableMessageRecallPreviewPrev <Plug>(MessageRecallPreviewPrev)
    map <Plug>DisableMessageRecallPreviewNext <Plug>(MessageRecallPreviewNext)
    map <Plug>DisableMessageRecallGoPrev      <Plug>(MessageRecallGoPrev)
    map <Plug>DisableMessageRecallGoNext      <Plug>(MessageRecallGoNext)
    autocmd User MessageRecallBuffer  map <buffer> <Leader>P <Plug>(MessageRecallGoPrev)
    autocmd User MessageRecallBuffer  map <buffer> <Leader>N <Plug>(MessageRecallGoNext)
    autocmd User MessageRecallPreview map <buffer> <Leader>P <Plug>(MessageRecallPreviewPrev)
    autocmd User MessageRecallPreview map <buffer> <Leader>N <Plug>(MessageRecallPreviewNext)

    autocmd User MessageRecallBuffer  unsilent echomsg '**** Buffer in' expand('%')
    autocmd User MessageRecallPreview unsilent echomsg '**** Preview in' expand('%')

