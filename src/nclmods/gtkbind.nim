# GTK 3 loaded by soname. The -dev headers are not required.
const
  GtkLib = "libgtk-3.so.0"
  GdkLib = "libgdk-3.so.0"
  GobjLib = "libgobject-2.0.so.0"
  GlibLib = "libglib-2.0.so.0"
  CairoLib = "libcairo.so.2"
  SvLib = "libgtksourceview-4.so.0"

proc gtk_init(argc, argv: pointer) {.importc, dynlib: GtkLib.}
proc gtk_main() {.importc, dynlib: GtkLib.}
proc gtk_main_quit() {.importc, dynlib: GtkLib.}
proc gtk_events_pending(): cint {.importc, dynlib: GtkLib.}
proc gtk_main_iteration(): cint {.importc, dynlib: GtkLib.}
proc gtk_window_new(typ: cint): pointer {.importc, dynlib: GtkLib.}
proc gtk_window_set_title(w: pointer, t: cstring) {.importc, dynlib: GtkLib.}
proc gtk_window_set_default_size(w: pointer, x, y: cint) {.importc, dynlib: GtkLib.}
proc gtk_window_set_position(w: pointer, p: cint) {.importc, dynlib: GtkLib.}
proc gtk_window_move(w: pointer, x, y: cint) {.importc, dynlib: GtkLib.}
proc gtk_window_set_resizable(w: pointer, v: cint) {.importc, dynlib: GtkLib.}
proc gtk_window_set_decorated(w: pointer, v: cint) {.importc, dynlib: GtkLib.}
proc gtk_window_present(w: pointer) {.importc, dynlib: GtkLib.}
proc gtk_window_add_accel_group(w, g: pointer) {.importc, dynlib: GtkLib.}
proc gtk_widget_show(w: pointer) {.importc, dynlib: GtkLib.}
proc gtk_widget_show_all(w: pointer) {.importc, dynlib: GtkLib.}
proc gtk_widget_hide(w: pointer) {.importc, dynlib: GtkLib.}
proc gtk_widget_destroy(w: pointer) {.importc, dynlib: GtkLib.}
proc gtk_widget_set_size_request(w: pointer, x, y: cint) {.importc, dynlib: GtkLib.}
proc gtk_widget_set_sensitive(w: pointer, v: cint) {.importc, dynlib: GtkLib.}
proc gtk_widget_set_tooltip_text(w: pointer, t: cstring) {.importc, dynlib: GtkLib.}
proc gtk_widget_set_hexpand(w: pointer, v: cint) {.importc, dynlib: GtkLib.}
proc gtk_widget_set_vexpand(w: pointer, v: cint) {.importc, dynlib: GtkLib.}
proc gtk_widget_set_margin_start(w: pointer, m: cint) {.importc, dynlib: GtkLib.}
proc gtk_widget_set_margin_end(w: pointer, m: cint) {.importc, dynlib: GtkLib.}
proc gtk_widget_set_margin_top(w: pointer, m: cint) {.importc, dynlib: GtkLib.}
proc gtk_widget_set_margin_bottom(w: pointer, m: cint) {.importc, dynlib: GtkLib.}
proc gtk_widget_set_can_focus(w: pointer, v: cint) {.importc, dynlib: GtkLib.}
proc gtk_widget_grab_focus(w: pointer) {.importc, dynlib: GtkLib.}
proc gtk_widget_get_window(w: pointer): pointer {.importc, dynlib: GtkLib.}
proc gtk_grab_add(w: pointer) {.importc, dynlib: GtkLib.}
proc gtk_grab_remove(w: pointer) {.importc, dynlib: GtkLib.}
proc gdk_window_get_origin(w: pointer, x, y: ptr cint): cint {.importc, dynlib: GdkLib.}
proc gtk_widget_set_app_paintable(w: pointer, v: cint) {.importc, dynlib: GtkLib.}
proc gtk_widget_add_events(w: pointer, ev: cint) {.importc, dynlib: GtkLib.}
proc gtk_widget_queue_draw(w: pointer) {.importc, dynlib: GtkLib.}
proc gtk_widget_get_screen(w: pointer): pointer {.importc, dynlib: GtkLib.}
proc gtk_widget_set_visual(w, v: pointer) {.importc, dynlib: GtkLib.}
proc gtk_widget_get_allocated_width(w: pointer): cint {.importc, dynlib: GtkLib.}
proc gtk_widget_get_allocated_height(w: pointer): cint {.importc, dynlib: GtkLib.}
proc gtk_widget_get_has_window(w: pointer): cint {.importc, dynlib: GtkLib.}
proc gtk_widget_get_visible(w: pointer): cint {.importc, dynlib: GtkLib.}
proc gtk_widget_get_mapped(w: pointer): cint {.importc, dynlib: GtkLib.}
proc gtk_widget_get_realized(w: pointer): cint {.importc, dynlib: GtkLib.}
proc gtk_widget_realize(w: pointer) {.importc, dynlib: GtkLib.}
proc gtk_widget_get_toplevel(w: pointer): pointer {.importc, dynlib: GtkLib.}
type
  GtkAllocation {.bycopy.} = object
    x, y, width, height: cint

proc gtk_widget_get_parent(w: pointer): pointer {.importc, dynlib: GtkLib.}
proc gtk_widget_queue_resize(w: pointer) {.importc, dynlib: GtkLib.}
proc gtk_widget_get_size_request(w: pointer, width, height: ptr cint) {.importc, dynlib: GtkLib.}
proc gtk_widget_get_preferred_height_for_width(w: pointer, width: cint, minimum, natural: ptr cint) {.importc, dynlib: GtkLib.}
proc gtk_widget_get_preferred_width(w: pointer, minimum, natural: ptr cint) {.importc, dynlib: GtkLib.}
proc gtk_widget_size_allocate(w: pointer, a: ptr GtkAllocation) {.importc, dynlib: GtkLib.}
proc gtk_widget_get_allocation(w: pointer, a: ptr GtkAllocation) {.importc, dynlib: GtkLib.}
proc gdk_window_get_width(w: pointer): cint {.importc, dynlib: GdkLib.}
proc gdk_window_get_height(w: pointer): cint {.importc, dynlib: GdkLib.}
proc gtk_scrolled_window_set_min_content_height(s: pointer, h: cint) {.importc, dynlib: GtkLib.}
proc gtk_scrolled_window_set_propagate_natural_width(s: pointer, v: cint) {.importc, dynlib: GtkLib.}
proc gtk_scrolled_window_set_min_content_width(s: pointer, w: cint) {.importc, dynlib: GtkLib.}
proc gtk_widget_get_style_context(w: pointer): pointer {.importc, dynlib: GtkLib.}
proc gtk_container_add(c, w: pointer) {.importc, dynlib: GtkLib.}
proc gtk_container_remove(c, w: pointer) {.importc, dynlib: GtkLib.}
proc gtk_container_get_children(c: pointer): pointer {.importc, dynlib: GtkLib.}
proc gtk_bin_get_child(b: pointer): pointer {.importc, dynlib: GtkLib.}
proc gtk_container_check_resize(c: pointer) {.importc, dynlib: GtkLib.}
proc gtk_box_new(orient, spacing: cint): pointer {.importc, dynlib: GtkLib.}
proc gtk_box_pack_start(b, w: pointer, expand, fill: cint, pad: cuint) {.importc, dynlib: GtkLib.}
proc gtk_box_reorder_child(b, w: pointer, pos: cint) {.importc, dynlib: GtkLib.}
proc gtk_layout_new(h, v: pointer): pointer {.importc, dynlib: GtkLib.}
proc gtk_layout_put(l, w: pointer, x, y: cint) {.importc, dynlib: GtkLib.}
proc gtk_flow_box_new(): pointer {.importc, dynlib: GtkLib.}
proc gtk_flow_box_insert(box, child: pointer, pos: cint) {.importc, dynlib: GtkLib.}
proc gtk_flow_box_set_selection_mode(box: pointer, mode: cint) {.importc, dynlib: GtkLib.}
proc gtk_flow_box_set_homogeneous(box: pointer, h: cint) {.importc, dynlib: GtkLib.}
proc gtk_flow_box_set_column_spacing(box: pointer, spacing: cuint) {.importc, dynlib: GtkLib.}
proc gtk_flow_box_set_row_spacing(box: pointer, spacing: cuint) {.importc, dynlib: GtkLib.}
proc gtk_flow_box_set_max_children_per_line(box: pointer, n: cuint) {.importc, dynlib: GtkLib.}
proc gtk_widget_set_halign(w: pointer, align: cint) {.importc, dynlib: GtkLib.}
proc gtk_widget_set_valign(w: pointer, align: cint) {.importc, dynlib: GtkLib.}
proc gtk_layout_move(l, w: pointer, x, y: cint) {.importc, dynlib: GtkLib.}
proc gtk_layout_set_size(l: pointer, w, h: cuint) {.importc, dynlib: GtkLib.}
proc gtk_fixed_new(): pointer {.importc, dynlib: GtkLib.}
proc gtk_fixed_put(f, w: pointer, x, y: cint) {.importc, dynlib: GtkLib.}
proc gtk_fixed_move(f, w: pointer, x, y: cint) {.importc, dynlib: GtkLib.}
proc gtk_frame_new(s: cstring): pointer {.importc, dynlib: GtkLib.}
proc gtk_frame_set_label(f: pointer, s: cstring) {.importc, dynlib: GtkLib.}
proc gtk_frame_set_shadow_type(f: pointer, t: cint) {.importc, dynlib: GtkLib.}
proc gtk_frame_set_label_align(f: pointer, x, y: cfloat) {.importc, dynlib: GtkLib.}
proc gtk_event_box_new(): pointer {.importc, dynlib: GtkLib.}
proc gtk_drawing_area_new(): pointer {.importc, dynlib: GtkLib.}
proc gtk_label_new(s: cstring): pointer {.importc, dynlib: GtkLib.}
proc gtk_label_set_text(l: pointer, s: cstring) {.importc, dynlib: GtkLib.}
proc gtk_label_set_xalign(l: pointer, x: cfloat) {.importc, dynlib: GtkLib.}
proc gtk_label_set_yalign(l: pointer, y: cfloat) {.importc, dynlib: GtkLib.}
proc gtk_label_set_line_wrap(l: pointer, v: cint) {.importc, dynlib: GtkLib.}
proc gtk_button_new_with_label(s: cstring): pointer {.importc, dynlib: GtkLib.}
proc gtk_button_set_label(b: pointer, s: cstring) {.importc, dynlib: GtkLib.}
proc gtk_button_set_use_underline(b: pointer, v: cint) {.importc, dynlib: GtkLib.}
proc gtk_button_set_relief(b: pointer, r: cint) {.importc, dynlib: GtkLib.}
proc gtk_spin_button_new_with_range(minv, maxv, step: cdouble): pointer {.importc, dynlib: GtkLib.}
proc gtk_spin_button_set_range(s: pointer, minv, maxv: cdouble) {.importc, dynlib: GtkLib.}
proc gtk_spin_button_set_increments(s: pointer, step, page: cdouble) {.importc, dynlib: GtkLib.}
proc gtk_spin_button_get_value(s: pointer): cdouble {.importc, dynlib: GtkLib.}
proc gtk_spin_button_set_value(s: pointer, v: cdouble) {.importc, dynlib: GtkLib.}
proc gtk_spin_button_set_numeric(s: pointer, v: cint) {.importc, dynlib: GtkLib.}
proc gtk_spin_button_set_digits(s: pointer, digits: cint) {.importc, dynlib: GtkLib.}
proc gtk_entry_new(): pointer {.importc, dynlib: GtkLib.}
proc gtk_entry_set_text(e: pointer, s: cstring) {.importc, dynlib: GtkLib.}
proc gtk_entry_get_text(e: pointer): cstring {.importc, dynlib: GtkLib.}
proc gtk_entry_set_placeholder_text(e: pointer, s: cstring) {.importc, dynlib: GtkLib.}
proc gtk_entry_set_visibility(e: pointer, v: cint) {.importc, dynlib: GtkLib.}
proc gtk_entry_set_alignment(e: pointer, x: cfloat) {.importc, dynlib: GtkLib.}
proc gtk_editable_set_editable(e: pointer, v: cint) {.importc, dynlib: GtkLib.}
proc gtk_text_view_new(): pointer {.importc, dynlib: GtkLib.}
proc gtk_text_view_get_buffer(v: pointer): pointer {.importc, dynlib: GtkLib.}
proc gtk_text_view_set_wrap_mode(v: pointer, m: cint) {.importc, dynlib: GtkLib.}
proc gtk_text_view_set_editable(v: pointer, e: cint) {.importc, dynlib: GtkLib.}
proc gtk_text_view_set_monospace(v: pointer, m: cint) {.importc, dynlib: GtkLib.}
proc gtk_text_view_set_cursor_visible(v: pointer, c: cint) {.importc, dynlib: GtkLib.}
proc gtk_text_view_scroll_to_iter(v, it: pointer, margin: cdouble, useAlign: cint,
  xa, ya: cdouble) {.importc, dynlib: GtkLib.}
proc gtk_text_buffer_set_text(b: pointer, t: cstring, n: cint) {.importc, dynlib: GtkLib.}
proc gtk_text_buffer_get_text(b, a, c: pointer, hidden: cint): cstring {.importc, dynlib: GtkLib.}
proc gtk_text_buffer_get_start_iter(b, it: pointer) {.importc, dynlib: GtkLib.}
proc gtk_text_buffer_get_end_iter(b, it: pointer) {.importc, dynlib: GtkLib.}
proc gtk_text_buffer_get_iter_at_line(b, it: pointer, line: cint) {.importc, dynlib: GtkLib.}
proc gtk_text_buffer_get_iter_at_line_offset(b, it: pointer, line, offset: cint) {.importc, dynlib: GtkLib.}
proc gtk_text_buffer_get_iter_at_offset(b, it: pointer, offset: cint) {.importc, dynlib: GtkLib.}
proc gtk_text_buffer_get_insert(b: pointer): pointer {.importc, dynlib: GtkLib.}
proc gtk_text_buffer_get_iter_at_mark(b, it, mark: pointer) {.importc, dynlib: GtkLib.}
proc gtk_text_iter_get_line(it: pointer): cint {.importc, dynlib: GtkLib.}
proc gtk_text_iter_get_line_offset(it: pointer): cint {.importc, dynlib: GtkLib.}
proc gtk_text_buffer_select_range(b, ins, bound: pointer) {.importc, dynlib: GtkLib.}
proc gtk_text_buffer_get_selection_bounds(b, a, c: pointer): cint {.importc, dynlib: GtkLib.}
proc gtk_text_iter_get_offset(it: pointer): cint {.importc, dynlib: GtkLib.}
proc gtk_text_buffer_place_cursor(b, it: pointer) {.importc, dynlib: GtkLib.}
proc gtk_widget_get_clipboard(w, atom: pointer): pointer {.importc, dynlib: GtkLib.}
proc gtk_text_buffer_copy_clipboard(b, clip: pointer) {.importc, dynlib: GtkLib.}
proc gtk_text_buffer_cut_clipboard(b, clip: pointer, editable: cint) {.importc, dynlib: GtkLib.}
proc gtk_text_buffer_paste_clipboard(b, clip, where: pointer, editable: cint) {.importc, dynlib: GtkLib.}
proc gtk_text_buffer_get_modified(b: pointer): cint {.importc, dynlib: GtkLib.}
proc gtk_text_buffer_set_modified(b: pointer, v: cint) {.importc, dynlib: GtkLib.}
proc gtk_text_buffer_insert(b, it: pointer, text: cstring, n: cint) {.importc, dynlib: GtkLib.}
proc gtk_text_buffer_delete(b, a, c: pointer) {.importc, dynlib: GtkLib.}
proc gtk_text_buffer_begin_user_action(b: pointer) {.importc, dynlib: GtkLib.}
proc gtk_text_buffer_end_user_action(b: pointer) {.importc, dynlib: GtkLib.}
proc gtk_scrolled_window_new(h, v: pointer): pointer {.importc, dynlib: GtkLib.}
proc gtk_scrolled_window_set_policy(s: pointer, h, v: cint) {.importc, dynlib: GtkLib.}
proc gtk_scrolled_window_set_overlay_scrolling(s: pointer, v: cint) {.importc, dynlib: GtkLib.}
proc gtk_scrolled_window_set_shadow_type(s: pointer, t: cint) {.importc, dynlib: GtkLib.}
proc gtk_scrolled_window_get_hadjustment(s: pointer): pointer {.importc, dynlib: GtkLib.}
proc gtk_scrolled_window_get_vadjustment(s: pointer): pointer {.importc, dynlib: GtkLib.}
proc gtk_adjustment_get_value(a: pointer): cdouble {.importc, dynlib: GtkLib.}
proc gtk_adjustment_set_value(a: pointer, v: cdouble) {.importc, dynlib: GtkLib.}
proc gtk_adjustment_get_lower(a: pointer): cdouble {.importc, dynlib: GtkLib.}
proc gtk_adjustment_get_upper(a: pointer): cdouble {.importc, dynlib: GtkLib.}
proc gtk_adjustment_get_page_size(a: pointer): cdouble {.importc, dynlib: GtkLib.}
proc gtk_check_button_new_with_label(s: cstring): pointer {.importc, dynlib: GtkLib.}
proc gtk_toggle_button_set_active(b: pointer, v: cint) {.importc, dynlib: GtkLib.}
proc gtk_toggle_button_new_with_label(s: cstring): pointer {.importc, dynlib: GtkLib.}
proc gtk_toggle_button_get_active(b: pointer): cint {.importc, dynlib: GtkLib.}
proc gtk_radio_button_new_with_label(group: pointer, s: cstring): pointer {.importc, dynlib: GtkLib.}
proc gtk_radio_button_new_with_label_from_widget(w: pointer, s: cstring): pointer {.importc, dynlib: GtkLib.}
proc gtk_radio_button_join_group(r, src: pointer) {.importc, dynlib: GtkLib.}
proc gtk_combo_box_text_new(): pointer {.importc, dynlib: GtkLib.}
proc gtk_combo_box_text_new_with_entry(): pointer {.importc, dynlib: GtkLib.}
proc gtk_combo_box_text_append_text(c: pointer, s: cstring) {.importc, dynlib: GtkLib.}
proc gtk_combo_box_text_remove_all(c: pointer) {.importc, dynlib: GtkLib.}
proc gtk_combo_box_text_get_active_text(c: pointer): cstring {.importc, dynlib: GtkLib.}
proc gtk_combo_box_set_active(c: pointer, i: cint) {.importc, dynlib: GtkLib.}
proc gtk_combo_box_get_active(c: pointer): cint {.importc, dynlib: GtkLib.}
proc gtk_list_box_new(): pointer {.importc, dynlib: GtkLib.}
proc gtk_list_box_insert(b, child: pointer, pos: cint) {.importc, dynlib: GtkLib.}
proc gtk_list_box_get_selected_row(b: pointer): pointer {.importc, dynlib: GtkLib.}
proc gtk_list_box_select_row(b, row: pointer) {.importc, dynlib: GtkLib.}
proc gtk_list_box_row_get_index(r: pointer): cint {.importc, dynlib: GtkLib.}
proc gtk_grid_new(): pointer {.importc, dynlib: GtkLib.}
proc gtk_grid_attach(g, child: pointer, left, top, w, h: cint) {.importc, dynlib: GtkLib.}
proc gtk_grid_set_row_spacing(g: pointer, s: cuint) {.importc, dynlib: GtkLib.}
proc gtk_grid_set_column_spacing(g: pointer, s: cuint) {.importc, dynlib: GtkLib.}
proc gtk_notebook_new(): pointer {.importc, dynlib: GtkLib.}
proc gtk_notebook_append_page(n, child, tab: pointer): cint {.importc, dynlib: GtkLib.}
proc gtk_notebook_set_tab_label_text(n, child: pointer, t: cstring) {.importc, dynlib: GtkLib.}
proc gtk_notebook_set_current_page(n: pointer, i: cint) {.importc, dynlib: GtkLib.}
proc gtk_notebook_set_show_tabs(n: pointer, show: cint) {.importc, dynlib: GtkLib.}
proc gtk_notebook_get_current_page(n: pointer): cint {.importc, dynlib: GtkLib.}
proc gtk_adjustment_new(value, lower, upper, step, page, pageSize: cdouble): pointer {.importc, dynlib: GtkLib.}
proc gtk_adjustment_configure(a: pointer, value, lower, upper, step, page, pageSize: cdouble) {.importc, dynlib: GtkLib.}
proc gtk_range_get_adjustment(r: pointer): pointer {.importc, dynlib: GtkLib.}
proc gtk_scrollbar_new(orient: cint, adjustment: pointer): pointer {.importc, dynlib: GtkLib.}
proc gtk_scale_new_with_range(orient: cint, minv, maxv, step: cdouble): pointer {.importc, dynlib: GtkLib.}
proc gtk_scale_set_draw_value(s: pointer, v: cint) {.importc, dynlib: GtkLib.}
proc gtk_range_set_value(r: pointer, v: cdouble) {.importc, dynlib: GtkLib.}
proc gtk_range_get_value(r: pointer): cdouble {.importc, dynlib: GtkLib.}
proc gtk_range_set_range(r: pointer, minv, maxv: cdouble) {.importc, dynlib: GtkLib.}
proc gtk_progress_bar_new(): pointer {.importc, dynlib: GtkLib.}
proc gtk_progress_bar_set_fraction(p: pointer, f: cdouble) {.importc, dynlib: GtkLib.}
proc gtk_tree_view_new(): pointer {.importc, dynlib: GtkLib.}
proc gtk_tree_view_set_headers_visible(t: pointer, v: cint) {.importc, dynlib: GtkLib.}
proc gtk_tree_view_append_column(t, col: pointer): cint {.importc, dynlib: GtkLib.}
proc gtk_tree_view_get_selection(t: pointer): pointer {.importc, dynlib: GtkLib.}
proc gtk_tree_view_expand_all(t: pointer) {.importc, dynlib: GtkLib.}
proc gtk_tree_view_column_new(): pointer {.importc, dynlib: GtkLib.}
proc gtk_tree_view_column_set_title(c: pointer, t: cstring) {.importc, dynlib: GtkLib.}
proc gtk_tree_view_column_pack_start(c, rend: pointer, expand: cint) {.importc, dynlib: GtkLib.}
proc gtk_tree_view_column_add_attribute(c, rend: pointer, attr: cstring, col: cint) {.importc, dynlib: GtkLib.}
proc gtk_tree_view_column_set_sizing(c: pointer, typ: cint) {.importc, dynlib: GtkLib.}
proc gtk_tree_view_column_set_fixed_width(c: pointer, w: cint) {.importc, dynlib: GtkLib.}
proc gtk_cell_renderer_text_new(): pointer {.importc, dynlib: GtkLib.}
proc gtk_tree_store_newv(n: cint, types: ptr uint64): pointer {.importc, dynlib: GtkLib.}
proc gtk_tree_store_append(store, iter, parent: pointer) {.importc, dynlib: GtkLib.}
proc gtk_tree_store_set_value(store, iter: pointer, col: cint, value: pointer) {.importc, dynlib: GtkLib.}
proc gtk_tree_store_clear(store: pointer) {.importc, dynlib: GtkLib.}
proc gtk_tree_view_set_model(t, m: pointer) {.importc, dynlib: GtkLib.}
proc gtk_tree_selection_get_selected(sel, model, iter: pointer): cint {.importc, dynlib: GtkLib.}
proc gtk_tree_selection_set_mode(sel: pointer, mode: cint) {.importc, dynlib: GtkLib.}
proc gtk_tree_model_get_value(model, iter: pointer, col: cint, value: pointer) {.importc, dynlib: GtkLib.}
proc gtk_menu_bar_new(): pointer {.importc, dynlib: GtkLib.}
proc gtk_menu_new(): pointer {.importc, dynlib: GtkLib.}
proc gtk_menu_item_new_with_label(s: cstring): pointer {.importc, dynlib: GtkLib.}
proc gtk_check_menu_item_new_with_mnemonic(s: cstring): pointer {.importc, dynlib: GtkLib.}
proc gtk_check_menu_item_set_active(i: pointer, v: cint) {.importc, dynlib: GtkLib.}
proc gtk_check_menu_item_get_active(i: pointer): cint {.importc, dynlib: GtkLib.}
proc gtk_menu_item_set_submenu(item, sub: pointer) {.importc, dynlib: GtkLib.}
proc gtk_menu_item_set_use_underline(item: pointer, v: cint) {.importc, dynlib: GtkLib.}
proc gtk_menu_shell_append(shell, child: pointer) {.importc, dynlib: GtkLib.}
proc gtk_separator_menu_item_new(): pointer {.importc, dynlib: GtkLib.}
proc gtk_menu_popup_at_pointer(menu, event: pointer) {.importc, dynlib: GtkLib.}
proc gtk_accel_group_new(): pointer {.importc, dynlib: GtkLib.}
proc gtk_widget_add_accelerator(w: pointer, signal: cstring, group: pointer,
  key: cuint, mods: cint, flags: cint) {.importc, dynlib: GtkLib.}
proc gtk_file_chooser_dialog_new(title: cstring, parent: pointer, action: cint,
  b1: cstring, r1: cint, b2: cstring, r2: cint, fin: pointer): pointer {.importc, dynlib: GtkLib.}
proc gtk_file_chooser_get_filename(c: pointer): cstring {.importc, dynlib: GtkLib.}
proc gtk_file_chooser_set_filename(c: pointer, f: cstring) {.importc, dynlib: GtkLib.}
proc gtk_file_chooser_set_current_name(c: pointer, n: cstring) {.importc, dynlib: GtkLib.}
proc gtk_file_chooser_set_do_overwrite_confirmation(c: pointer, v: cint) {.importc, dynlib: GtkLib.}
proc gtk_file_chooser_add_filter(c, f: pointer) {.importc, dynlib: GtkLib.}
proc gtk_file_filter_new(): pointer {.importc, dynlib: GtkLib.}
proc gtk_file_filter_set_name(f: pointer, n: cstring) {.importc, dynlib: GtkLib.}
proc gtk_file_filter_add_pattern(f: pointer, p: cstring) {.importc, dynlib: GtkLib.}
proc gtk_dialog_run(d: pointer): cint {.importc, dynlib: GtkLib.}
proc gtk_dialog_add_button(d: pointer, text: cstring, response: cint): pointer {.importc, dynlib: GtkLib.}
proc gtk_dialog_new_with_buttons(title: cstring, parent: pointer, flags: cint,
  b1: cstring, r1: cint, b2: cstring, r2: cint, fin: pointer): pointer {.importc, dynlib: GtkLib.}
proc gtk_dialog_get_content_area(d: pointer): pointer {.importc, dynlib: GtkLib.}
proc gtk_message_dialog_new(parent: pointer, flags, typ, buttons: cint, fmt, msg: cstring): pointer {.importc, dynlib: GtkLib.}
proc gtk_css_provider_new(): pointer {.importc, dynlib: GtkLib.}
proc gtk_css_provider_load_from_data(p: pointer, data: cstring, len: clong, err: pointer): cint {.importc, dynlib: GtkLib.}
proc gtk_style_context_add_provider(ctx, prov: pointer, prio: cuint) {.importc, dynlib: GtkLib.}
proc gtk_widget_get_preferred_size(w, minimum, natural: pointer) {.importc, dynlib: GtkLib.}

proc gdk_screen_get_rgba_visual(screen: pointer): pointer {.importc, dynlib: GdkLib.}
proc gdk_event_get_coords(ev: pointer, x, y: ptr cdouble): cint {.importc, dynlib: GdkLib.}
proc gdk_event_get_root_coords(ev: pointer, x, y: ptr cdouble): cint {.importc, dynlib: GdkLib.}
proc gdk_event_get_button(ev: pointer, b: ptr cuint): cint {.importc, dynlib: GdkLib.}
proc gdk_event_get_state(ev: pointer, state: ptr cuint): cint {.importc, dynlib: GdkLib.}
proc gdk_event_get_keyval(ev: pointer, key: ptr cuint): cint {.importc, dynlib: GdkLib.}
proc gdk_keyval_to_lower(key: cuint): cuint {.importc, dynlib: GdkLib.}
proc gdk_atom_intern(name: cstring, onlyIfExists: cint): pointer {.importc, dynlib: GdkLib.}
proc gdk_event_get_scroll_deltas(ev: pointer, dx, dy: ptr cdouble): cint {.importc, dynlib: GdkLib.}
proc gdk_event_get_scroll_direction(ev: pointer, dir: ptr cuint): cint {.importc, dynlib: GdkLib.}
proc gdk_event_get_time(ev: pointer): cuint {.importc, dynlib: GdkLib.}
proc gdk_window_new(parent, attr: pointer, mask: cint): pointer {.importc, dynlib: GdkLib.}
proc gdk_window_show(w: pointer) {.importc, dynlib: GdkLib.}
proc gdk_window_raise(w: pointer) {.importc, dynlib: GdkLib.}
proc gdk_window_move_resize(w: pointer, x, y, width, height: cint) {.importc, dynlib: GdkLib.}
proc gdk_window_set_user_data(w, data: pointer) {.importc, dynlib: GdkLib.}
proc gdk_window_focus(w: pointer, t: cuint) {.importc, dynlib: GdkLib.}
proc gdk_window_get_position(w: pointer, x, y: ptr cint) {.importc, dynlib: GdkLib.}
proc gtk_layout_get_bin_window(l: pointer): pointer {.importc, dynlib: GtkLib.}

proc g_signal_connect_data(obj: pointer, sig: cstring, cb: pointer, data: pointer,
  destroy: pointer, flags: cint): uint64 {.importc, dynlib: GobjLib.}
proc g_object_ref(o: pointer): pointer {.importc, dynlib: GobjLib.}
proc g_object_unref(o: pointer) {.importc, dynlib: GobjLib.}
proc g_value_init(v: pointer, t: uint64) {.importc, dynlib: GobjLib.}
proc g_value_unset(v: pointer) {.importc, dynlib: GobjLib.}
proc g_value_set_string(v: pointer, s: cstring) {.importc, dynlib: GobjLib.}
proc g_value_set_int(v: pointer, n: cint) {.importc, dynlib: GobjLib.}
proc g_value_get_int(v: pointer): cint {.importc, dynlib: GobjLib.}
proc g_value_get_string(v: pointer): cstring {.importc, dynlib: GobjLib.}

proc g_timeout_add(ms: cuint, fn: pointer, data: pointer): cuint {.importc, dynlib: GlibLib.}
proc g_source_remove(tag: cuint): cint {.importc, dynlib: GlibLib.}
proc g_free(p: pointer) {.importc, dynlib: GlibLib.}
proc g_list_free(l: pointer) {.importc, dynlib: GlibLib.}

proc cairo_set_source_rgba(cr: pointer, r, g, b, a: cdouble) {.importc, dynlib: CairoLib.}
proc cairo_set_operator(cr: pointer, op: cint) {.importc, dynlib: CairoLib.}
proc cairo_paint(cr: pointer) {.importc, dynlib: CairoLib.}
proc cairo_rectangle(cr: pointer, x, y, w, h: cdouble) {.importc, dynlib: CairoLib.}
proc cairo_fill(cr: pointer) {.importc, dynlib: CairoLib.}
proc cairo_stroke(cr: pointer) {.importc, dynlib: CairoLib.}
proc cairo_set_line_width(cr: pointer, w: cdouble) {.importc, dynlib: CairoLib.}
proc cairo_translate(cr: pointer, x, y: cdouble) {.importc, dynlib: CairoLib.}
proc cairo_move_to(cr: pointer, x, y: cdouble) {.importc, dynlib: CairoLib.}
proc cairo_line_to(cr: pointer, x, y: cdouble) {.importc, dynlib: CairoLib.}
proc cairo_show_text(cr: pointer, s: cstring) {.importc, dynlib: CairoLib.}
proc cairo_select_font_face(cr: pointer, family: cstring, slant, weight: cint) {.importc, dynlib: CairoLib.}
proc cairo_set_font_size(cr: pointer, s: cdouble) {.importc, dynlib: CairoLib.}

proc gtk_source_language_manager_get_default(): pointer {.importc, dynlib: SvLib.}
proc gtk_source_language_manager_set_search_path(m: pointer, dirs: cstringArray) {.importc, dynlib: SvLib.}
proc gtk_source_language_manager_get_language(m: pointer, id: cstring): pointer {.importc, dynlib: SvLib.}
proc gtk_source_buffer_new(table: pointer): pointer {.importc, dynlib: SvLib.}
proc gtk_source_buffer_new_with_language(lang: pointer): pointer {.importc, dynlib: SvLib.}
proc gtk_source_buffer_set_language(b, lang: pointer) {.importc, dynlib: SvLib.}
proc gtk_source_buffer_set_highlight_syntax(b: pointer, v: cint) {.importc, dynlib: SvLib.}
proc gtk_source_buffer_set_style_scheme(b, scheme: pointer) {.importc, dynlib: SvLib.}
proc gtk_source_style_scheme_manager_get_default(): pointer {.importc, dynlib: SvLib.}
proc gtk_source_style_scheme_manager_prepend_search_path(m: pointer, path: cstring) {.importc, dynlib: SvLib.}
proc gtk_source_style_scheme_manager_force_rescan(m: pointer) {.importc, dynlib: SvLib.}
proc gtk_source_style_scheme_manager_get_scheme(m: pointer, id: cstring): pointer {.importc, dynlib: SvLib.}
proc gtk_source_buffer_undo(b: pointer) {.importc, dynlib: SvLib.}
proc gtk_source_buffer_redo(b: pointer) {.importc, dynlib: SvLib.}
proc gtk_source_buffer_can_undo(b: pointer): cint {.importc, dynlib: SvLib.}
proc gtk_source_buffer_can_redo(b: pointer): cint {.importc, dynlib: SvLib.}
proc gtk_source_view_new_with_buffer(b: pointer): pointer {.importc, dynlib: SvLib.}
proc gtk_source_view_set_show_line_numbers(v: pointer, s: cint) {.importc, dynlib: SvLib.}
proc gtk_source_view_set_highlight_current_line(v: pointer, s: cint) {.importc, dynlib: SvLib.}
proc gtk_source_view_set_tab_width(v: pointer, w: cuint) {.importc, dynlib: SvLib.}
proc gtk_source_view_set_indent_width(v: pointer, w: cint) {.importc, dynlib: SvLib.}
proc gtk_source_view_set_insert_spaces_instead_of_tabs(v: pointer, s: cint) {.importc, dynlib: SvLib.}
proc gtk_source_view_set_auto_indent(v: pointer, s: cint) {.importc, dynlib: SvLib.}
proc gtk_source_view_set_show_right_margin(v: pointer, s: cint) {.importc, dynlib: SvLib.}
proc gtk_source_view_set_right_margin_position(v: pointer, pos: cuint) {.importc, dynlib: SvLib.}
proc gtk_text_view_get_line_yrange(v, it: pointer, y, h: ptr cint) {.importc, dynlib: GtkLib.}
proc gtk_text_view_buffer_to_window_coords(v: pointer, win, bx, by: cint, wx, wy: ptr cint) {.importc, dynlib: GtkLib.}
proc gtk_text_buffer_get_line_count(b: pointer): cint {.importc, dynlib: GtkLib.}

const GtkTextWindowText* = 2

type
  GtkRequisition {.bycopy.} = object
    width, height: cint
  GList {.bycopy.} = object
    data: pointer
    next: ptr GList
    prev: ptr GList
  GValue {.bycopy.} = object
    gtype: uint64
    d0: uint64
    d1: uint64
  GtkTreeIter {.bycopy.} = object
    stamp: cint
    pad: cint
    userData: pointer
    userData2: pointer
    userData3: pointer

const
  GTypeString = 64'u64
  GTypeInt = 24'u64
  GtkOrientHorizontal = 0
  GtkOrientVertical = 1
  GtkPolicyAuto = 1
  GtkPolicyNever = 2
  GtkAlignStart = 1
  GtkAlignCenter = 3
  GtkShadowNone = 0
  GtkShadowIn = 1
  GtkShadowOut = 2
  GtkShadowEtchedIn = 3
  GtkWinPosCenter = 1
  GtkResponseAccept = -3
  GtkResponseOk = -5
  GtkResponseCancel = -6
  GtkResponseYes = -8
  GtkResponseNo = -9
  GtkMessageInfo = 0
  GtkMessageWarning = 1
  GtkMessageQuestion = 2
  GtkMessageError = 3
  GtkButtonsNone = 0
  GtkDialogModal = 1
  GtkFileOpen = 0
  GtkFileSave = 1
  GtkAccelVisible = 1
  GdkShiftMask = 1'u32
  GdkControlMask = 4'u32
  GdkMod1Mask = 8'u32
  GdkButtonPressMask = 256
  GdkButtonReleaseMask = 512
  GdkPointerMotionMask = 4
  GdkButtonMotionMask = 32
  GdkKeyPressMask = 1024
  GdkScrollMask = 8192
  CairoOpSource = 1
  CairoOpOver = 2
  CssPrioApp = 600'u32
  GdkKeyLeft = 0xff51'u32
  GdkKeyUp = 0xff52'u32
  GdkKeyRight = 0xff53'u32
  GdkKeyDown = 0xff54'u32
  GdkKeyEscape = 0xff1b'u32
  GdkKeyDelete = 0xffff'u32
  GdkKeyReturn = 0xff0d'u32
  GdkKeyBackSpace = 0xff08'u32
  Gdk2ButtonPress = 5
  GdkInputOnly = 1
  GdkWindowChild = 2
  GdkWaXY = 12

type
  GdkWindowAttr {.bycopy.} = object
    title: cstring
    eventMask: cint
    x, y, width, height: cint
    wclass: cint
    visual: pointer
    windowType: cint
    cursor: pointer
    wmclassName: cstring
    wmclassClass: cstring
    overrideRedirect: cint
    typeHint: cint

proc connect(widget: pointer, signal: string, cb: pointer, id: int) =
  if widget == nil: return
  discard g_signal_connect_data(widget, signal.cstring, cb, cast[pointer](id), nil, 0)

proc connectAfter(widget: pointer, signal: string, cb: pointer, id: int) =
  if widget == nil: return
  # G_CONNECT_AFTER so a draw handler paints on top of the theme background
  # and still underneath child widgets.
  discard g_signal_connect_data(widget, signal.cstring, cb, cast[pointer](id), nil, 1)

proc cssLoad(provider: pointer, css: string) =
  if provider == nil: return
  discard gtk_css_provider_load_from_data(provider, css.cstring, -1, nil)

proc eventTypeOf(ev: pointer): cint =
  if ev == nil: return 0
  copyMem(addr result, ev, sizeof(cint))

proc takeString(p: cstring): string =
  if p == nil: return ""
  result = $p
  g_free(p)

var gtkStarted = false

proc ensureGtk*() =
  if gtkStarted: return
  # XFCE loads appmenu-gtk-module, which sets gtk-shell-shows-menubar and
  # collapses every GtkMenuBar so the panel can draw it. The IDE menu stays
  # in the window. The module reads this while gtk_init loads GTK_MODULES.
  putEnv("UBUNTU_MENUPROXY", "0")
  gtk_init(nil, nil)
  gtkStarted = true
