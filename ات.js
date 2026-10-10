{
  "namespace": "hud",
  "quick_utility_drop_one@common_buttons.light_text_button": {
    "$button_text": "Q",
    "$pressed_button_name": "button.hotbar_drop_one",
    "size": [34, 28],
    "anchor_from": "bottom_middle",
    "anchor_to": "bottom_middle",
    "offset": [-118, -12],
    "layer": 100,
    "button_mappings": [
      {
        "from_button_id": "button.menu_select",
        "to_button_id": "button.hotbar_drop_one",
        "mapping_type": "pressed"
      }
    ]
  },
  "quick_utility_drop_stack@common_buttons.light_text_button": {
    "$button_text": "Stack",
    "$pressed_button_name": "button.hotbar_drop_all",
    "size": [44, 28],
    "anchor_from": "bottom_middle",
    "anchor_to": "bottom_middle",
    "offset": [118, -12],
    "layer": 100,
    "button_mappings": [
      {
        "from_button_id": "button.menu_select",
        "to_button_id": "button.hotbar_drop_all",
        "mapping_type": "pressed"
      }
    ]
  },
  "root_panel": {
    "modifications": [
      {
        "array_name": "controls",
        "operation": "insert_front",
        "value": [
          {
            "quick_utility_drop_one@hud.quick_utility_drop_one": {}
          },
          {
            "quick_utility_drop_stack@hud.quick_utility_drop_stack": {}
          }
        ]
      }
    ]
  }
}
