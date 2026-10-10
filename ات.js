{
  "namespace": "hud",
  "quick_utility_drop_one@common.button": {
    "$button_text": "Q",
    "size": [32, 28],
    "anchor_from": "bottom_left",
    "anchor_to": "bottom_left",
    "offset": [12, -70],
    "layer": 100,
    "controls": [
      {
        "button_label@common.button_label": {
          "text": "$button_text",
          "layer": 101
        }
      }
    ],
    "button_mappings": [
      {
        "from_button_id": "button.menu_select",
        "to_button_id": "button.menu_select",
        "mapping_type": "global"
      }
    ]
  },
  "quick_utility_drop_stack@common.button": {
    "$button_text": "Stack",
    "size": [44, 28],
    "anchor_from": "bottom_left",
    "anchor_to": "bottom_left",
    "offset": [48, -70],
    "layer": 100,
    "controls": [
      {
        "button_label@common.button_label": {
          "text": "$button_text",
          "layer": 101
        }
      }
    ],
    "button_mappings": [
      {
        "from_button_id": "button.menu_select",
        "to_button_id": "button.menu_select",
        "mapping_type": "global"
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
