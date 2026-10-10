import { EquipmentSlot, system, world } from "@minecraft/server";
import { ActionFormData } from "@minecraft/server-ui";

const TARGET_TTL_MS = 10 * 60 * 1000;
const activeContainers = new Map();
const menuOpenFor = new Set();

function getPlayerInventory(player) {
  try {
    return player.getComponent("minecraft:inventory")?.container;
  } catch {
    return undefined;
  }
}

function getMainhand(player) {
  try {
    return player.getComponent("minecraft:equippable")?.getEquipment(EquipmentSlot.Mainhand);
  } catch {
    return undefined;
  }
}

function getActiveContainer(player) {
  const target = activeContainers.get(player.id);
  if (!target) return undefined;

  if (Date.now() - target.openedAt > TARGET_TTL_MS) {
    activeContainers.delete(player.id);
    return undefined;
  }

  try {
    return target.block.getComponent("minecraft:inventory")?.container;
  } catch {
    return undefined;
  }
}

function notify(player, message) {
  try {
    player.sendMessage(`§7[Quick Utility]§r ${message}`);
  } catch {
    // The player may have disconnected between a form response and this call.
  }
}

function compareItems(a, b) {
  const typeOrder = a.typeId.localeCompare(b.typeId);
  if (typeOrder !== 0) return typeOrder;

  const nameOrder = (a.nameTag ?? "").localeCompare(b.nameTag ?? "");
  if (nameOrder !== 0) return nameOrder;

  return b.amount - a.amount;
}

function sortContainer(container) {
  if (!container) return false;

  const sorted = [];
  for (let slot = 0; slot < container.size; slot++) {
    const item = container.getItem(slot);
    if (item) sorted.push(item.clone());
  }

  sorted.sort(compareItems);

  for (let slot = 0; slot < container.size; slot++) {
    container.setItem(slot, sorted[slot]);
  }

  return true;
}

function sortInventory(player) {
  const inventory = getPlayerInventory(player);
  if (!inventory) {
    notify(player, "تعذر الوصول إلى حقيبتك.");
    return;
  }

  try {
    sortContainer(inventory);
    notify(player, "تم ترتيب الحقيبة حسب نوع العنصر.");
  } catch (error) {
    console.warn(`[Quick Utility] sortInventory failed: ${error}`);
    notify(player, "تعذر ترتيب الحقيبة؛ قد تكون الحقيبة غير متاحة الآن.");
  }
}

function sortChest(player) {
  const container = getActiveContainer(player);
  if (!container) {
    notify(player, "افتح صندوقاً أولاً، ثم أعد المحاولة خلال عشر دقائق.");
    return;
  }

  try {
    sortContainer(container);
    notify(player, "تم ترتيب الحاوية حسب نوع العنصر.");
  } catch (error) {
    console.warn(`[Quick Utility] sortChest failed: ${error}`);
    notify(player, "تعذر ترتيب الحاوية؛ تأكد أنها ما زالت محمّلة ومتاحة.");
  }
}

function transferInventoryToContainer(player, matchesTypeId) {
  const source = getPlayerInventory(player);
  const destination = getActiveContainer(player);

  if (!source) {
    notify(player, "تعذر الوصول إلى حقيبتك.");
    return;
  }
  if (!destination) {
    notify(player, "افتح صندوقاً أولاً، ثم أعد المحاولة خلال عشر دقائق.");
    return;
  }

  let moved = 0;
  try {
    for (let slot = 0; slot < source.size; slot++) {
      const item = source.getItem(slot);
      if (!item || (matchesTypeId && item.typeId !== matchesTypeId)) continue;

      const originalAmount = item.amount;
      const remainder = destination.addItem(item.clone());
      const remainingAmount = remainder?.amount ?? 0;
      const insertedAmount = originalAmount - remainingAmount;
      if (insertedAmount <= 0) continue;

      source.setItem(slot, remainder);
      moved += insertedAmount;
    }
  } catch (error) {
    console.warn(`[Quick Utility] transfer failed: ${error}`);
    notify(player, `توقف النقل بعد نقل ${moved} عنصر؛ تحقق من الحاوية وحقيبتك.`);
    return;
  }

  if (matchesTypeId) {
    notify(player, moved
      ? `نُقل ${moved} من العناصر المطابقة (${matchesTypeId}).`
      : `لم يُنقل شيء من ${matchesTypeId}؛ قد تكون الحاوية ممتلئة.`);
  } else {
    notify(player, moved
      ? `تم النقل السريع: ${moved} عنصر إلى الحاوية.`
      : "لم يُنقل شيء؛ الحاوية ممتلئة أو لا توجد عناصر قابلة للنقل.");
  }
}

function moveMatchingItems(player) {
  const held = getMainhand(player);
  if (!held) {
    notify(player, "أمسك العنصر المطلوب نقله في يدك الرئيسية أولاً.");
    return;
  }

  transferInventoryToContainer(player, held.typeId);
}

function dropHeld(player, wholeStack) {
  const equipment = player.getComponent("minecraft:equippable");
  const held = equipment?.getEquipment(EquipmentSlot.Mainhand);
  if (!held) {
    notify(player, "لا يوجد عنصر في اليد الرئيسية.");
    return;
  }

  const original = held.clone();
  const dropped = held.clone();
  if (!wholeStack) dropped.amount = 1;

  let remainder;
  if (!wholeStack && held.amount > 1) {
    remainder = held.clone();
    remainder.amount -= 1;
  }

  try {
    if (!equipment.setEquipment(EquipmentSlot.Mainhand, remainder)) {
      notify(player, "لم أتمكن من تحديث العنصر في يدك.");
      return;
    }

    const direction = player.getViewDirection();
    const location = player.location;
    const spawnAt = {
      x: location.x + direction.x * 0.65,
      y: location.y + 0.7 + direction.y * 0.35,
      z: location.z + direction.z * 0.65
    };

    try {
      player.dimension.spawnItem(dropped, spawnAt);
    } catch (error) {
      equipment.setEquipment(EquipmentSlot.Mainhand, original);
      throw error;
    }
  } catch (error) {
    console.warn(`[Quick Utility] drop failed: ${error}`);
    notify(player, "تعذر رمي العنصر.");
  }
}

function showMenu(player) {
  if (menuOpenFor.has(player.id)) {
    notify(player, "القائمة مفتوحة بالفعل.");
    return;
  }

  const hasContainer = Boolean(getActiveContainer(player));
  const form = new ActionFormData()
    .title("Quick Utility")
    .body(hasContainer
      ? "اختر إجراءً للحاوية التي فتحتها مؤخراً."
      : "افتح صندوقاً أولاً لاستخدام إجراءات الصندوق.");
  const actions = [];

  if (hasContainer) {
    form.button("Sort Chest");
    actions.push(() => sortChest(player));
    form.button("Quick Transfer: Inventory → Chest");
    actions.push(() => transferInventoryToContainer(player));
    form.button("Move Matching Items");
    actions.push(() => moveMatchingItems(player));
  }

  form.button("Sort Inventory");
  actions.push(() => sortInventory(player));

  menuOpenFor.add(player.id);
  system.runTimeout(() => {
    try {
      form.show(player)
        .then((response) => {
          if (response.canceled || response.selection === undefined) return;
          actions[response.selection]?.();
        })
        .catch((error) => {
          console.warn(`[Quick Utility] form could not be shown: ${error}`);
          notify(player, "تعذر عرض القائمة الآن. أغلق أي نافذة أخرى ثم استخدم /scriptevent utility:menu.");
        })
        .finally(() => menuOpenFor.delete(player.id));
    } catch (error) {
      menuOpenFor.delete(player.id);
      console.warn(`[Quick Utility] form failed: ${error}`);
      notify(player, "تعذر فتح القائمة الآن.");
    }
  }, 1);
}

function runAction(player, action) {
  switch (action) {
    case "menu":
      showMenu(player);
      break;
    case "drop_one":
      dropHeld(player, false);
      break;
    case "drop_stack":
      dropHeld(player, true);
      break;
    case "sort_inventory":
      sortInventory(player);
      break;
    case "sort_chest":
      sortChest(player);
      break;
    case "quick_transfer":
      transferInventoryToContainer(player);
      break;
    case "move_matching":
      moveMatchingItems(player);
      break;
    default:
      notify(player, "إجراء غير معروف.");
  }
}

world.afterEvents.blockContainerOpened.subscribe((event) => {
  const entity = event.openSource?.entity;
  if (!entity || entity.typeId !== "minecraft:player") return;

  const player = entity;
  activeContainers.set(player.id, {
    block: event.block,
    openedAt: Date.now()
  });

  showMenu(player);
});

system.afterEvents.scriptEventReceive.subscribe((event) => {
  if (!event.id.startsWith("utility:")) return;

  const player = event.sourceEntity;
  if (!player || player.typeId !== "minecraft:player") return;

  runAction(player, event.id.slice("utility:".length));
});
