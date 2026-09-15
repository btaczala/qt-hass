.pragma library

// A "navigate" action ({ action: "navigate", page: "LivingRoom.qml" }) from
// `item`: shows the page of the Dashboard `item` is in whose source is `page`.
// Returns whether it did.
function navigate(item, page) {
    for (let parent = item?.parent; parent; parent = parent.parent) {
        if (typeof parent.showPage === "function")
            return parent.showPage(page);
    }
    console.warn(`navigate to ${page}: not inside a dashboard`);
    return false;
}
