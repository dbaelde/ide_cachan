open Gobject.Data
open Core

class virtual item_list (root:'a set) = object(self)
    method virtual name : string
    method private iter f =
        let rec _iter item =
            match item#children with
            | [] -> f item
            | _  -> List.iter _iter item#children
        in
        _iter root
    method virtual private filter : 'a -> bool
    method get =
        let items = ref [] in
        let _filter =
            fun item -> if self#filter item then items := item::!items in
        self#iter _filter;
        !items
end

class all_items (root:'a set) = object
    inherit item_list root
    method name = "- All -"
    method filter _ = true
end

(* This is the miller column type gui item to navigate the hierarchy *)
class navlist ~packing ~root =
    let hbox = GPack.hbox ~packing () in
    let gset_data_func renderer column (model:GTree.model) iter =
        let set:gset = model#get ~row:iter ~column in
        renderer#set_properties [`TEXT set#name]
    in
    let item_list_data_func renderer column (model:GTree.model) iter =
        let il:item_list = model#get ~row:iter ~column in
        renderer#set_properties [`TEXT il#name]
    in
    let make_view model column data_func =
        let view = GTree.view ~model ~packing:hbox#add () in
        let renderer = GTree.cell_renderer_text [] in
        let cell_data_func = data_func renderer column in
        let viewcol = GTree.view_column ~renderer:(renderer, []) () in
        viewcol#set_cell_data_func renderer cell_data_func;
        ignore(view#append_column viewcol);
        view
    in
    let _cols = new GTree.column_list in
    let _col1 = _cols#add caml
    and _col2 = _cols#add caml
    and _col3 = _cols#add caml in
    let _model1 = GTree.tree_store _cols
    and _model2 = GTree.list_store _cols
    and _model3 = GTree.list_store _cols in
    let _view1 = make_view _model1 _col1 gset_data_func
    and _view2 = make_view _model2 _col2 item_list_data_func
    and _view3 = make_view _model3 _col3 gset_data_func in
    object(self)
        val cols = _cols
        val col1 = _col1
        val col2 = _col2
        val col3 = _col3
        val model1 = _model1
        val model2 = _model2
        val model3 = _model3
        val view1 = _view1
        val view2 = _view2
        val view3 = _view3

        (** Sets the data in the hierarchy tree *)
        method private fill_tree (data:gset) =
            model1#clear ();
            let rec fill ?(parent:Gtk.tree_iter option) (value:gset) =
                let iter = match parent with
                | Some(p) -> model1#append ~parent:p ()
                | None -> model1#append ()
                in
                model1#set ~row:iter ~column:col1 value;
                List.iter (fun a -> fill ~parent:iter a) value#children
            in
            fill data

        (** Sets the data in the method lists col *)
        method private fill_lists lists =
            model2#clear ();
            let fill (value:item_list) =
                let iter = model2#append () in
                model2#set ~row:iter ~column:col2 value
            in
            List.iter fill lists

        (** Sets the data in the methods col *)
        method private fill_methods methods =
            model3#clear ();
            let fill (value:gset) =
                let iter = model3#append () in
                model3#set ~row:iter ~column:col3 value
            in
            List.iter fill methods

        (** Changes the column title to title *)
        method set_column_title ~col ~title () =
            match col with
            | 1 -> (view1#get_column 0)#set_title title
            | 2 -> (view2#get_column 0)#set_title title
            | 3 -> (view3#get_column 0)#set_title title
            | _ -> failwith (Printf.sprintf "No such column (%i)" col)

        method private item_selected () =
            model3#clear ();
            let selection = view1#selection in
            let get path =
                let row = model1#get_iter path in
                model1#get ~row ~column:col1
            in
            match selection#get_selected_rows with
            | [p] -> self#fill_lists [(new all_items (get p):> item_list)]
            | _ -> ()

        method private list_selected () =
            let selection = view2#selection in
            let get path =
                let row = model2#get_iter path in
                model2#get ~row ~column:col2
            in
            match selection#get_selected_rows with
            | [p] -> self#fill_methods ((get p)#get)
            | _ -> ()

        method private method_selected () =
            let selection = view3#selection in
            let get path =
                let row = model3#get_iter path in
                model3#get ~row ~column:col3
            in
            match selection#get_selected_rows with
            | [p] -> Printf.printf "%s\n" ((get p)#to_string)
            | _ -> ()

        initializer
            self#fill_tree root;
            ignore(view1#selection#connect#changed
                ~callback:self#item_selected);
            ignore(view2#selection#connect#changed
                ~callback:self#list_selected);
            ignore(view3#selection#connect#changed
                ~callback:self#method_selected);
    end
;;
