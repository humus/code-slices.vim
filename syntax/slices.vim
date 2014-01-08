
hi link group_reg WarningMsg
hi link group_name String
hi link slice_reg Question
hi link slice_name String


syn sync fromstart

syn match group_name /\v\C(^Group)@<=.*/
syn match slice_name /\v\C(^Slice)@<=.*/
syn region group_reg start=/\v\C^Group/ end=/$/ contains=group_name
syn region slice_reg start=/\v\C^(Fluent)?Slice/ end=/$/ contains=slice_name
