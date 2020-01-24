
#todo: move this file into gizmo's dlr-binding subtree.  make dlr find it by symlinking dlr.tcl in gizmo tree.

::dlr::typedef  int  gint

::dlr::typedef  u32  enum

::dlr::typedef  enum  GIRepositoryLoadFlags
::dlr::declareCallToNative  applyScript  gi  {ptr asInt}  g_irepository_require  {
    {in     byVal   ptr                     repository      asInt}
    {in     byPtr   ascii                   namespace       asString}
    {in     byPtr   ascii                   version         asString}
    {in     byVal   GIRepositoryLoadFlags   flags           asInt}
    {out    byPtr   ptr                     error           asInt}
}
#todo: error handling

::dlr::declareCallToNative  applyScript  gi  {ptr asInt}  g_irepository_find_by_name  {
    {in     byVal   ptr                     repository      asInt}
    {in     byPtr   ascii                   namespace       asString}
    {in     byPtr   ascii                   name            asString}
}

::dlr::declareCallToNative  applyScript  gi  {gint asInt}  g_callable_info_get_n_args  {
    {in     byVal   ptr                     callable      asInt}
}

# this does yield the same default repo pointer as the GI lib linked at compile time, in the same process, same attempt.
::dlr::declareCallToNative  applyScript  gi  {ptr asInt}  g_irepository_get_default  {}

::dlr::declareCallToNative  applyScript  gi  {ptr asInt}  g_irepository_get_c_prefix  {
    {in     byVal   ptr                     repository      asInt}
    {in     byPtr   ascii                   namespace       asString}
}

::dlr::declareCallToNative  applyScript  gi  {ptr asInt}  g_irepository_get_shared_library  {
    {in     byVal   ptr                     repository      asInt}
    {in     byPtr   ascii                   namespace       asString}
}
