"use strict";
// Fictional, in-memory examples. No clipboard APIs, storage, analytics or network requests.
const examples = [
  { id: "paper", kind: "image", title: "纸的灵感.png", source: "预览", time: "刚刚", favorite: false, text: "纸的灵感 设计参考", meta: "PNG · 示例插画" },
  { id: "note", kind: "text", title: "把灵感留在手边", source: "备忘录", time: "2 分钟前", favorite: false, text: "把灵感留在手边\n\n好工具不需要占据注意力。\n它只需要在你需要的时候，恰好出现。\n\n随手复制，随时找回。", meta: "文字 · 虚构示例" },
  { id: "link", kind: "link", title: "关于下一次创作", source: "浏览器", time: "8 分钟前", favorite: false, text: "https://example.com/ideas\n\n留到下一次创作时，再来看看。", meta: "链接 · 虚构示例" },
  { id: "favorite", kind: "text", title: "一段常用的回复", source: "文本编辑", time: "今天", favorite: true, text: "谢谢分享，已收到。\n我会整理一下想法，稍后回复你。", meta: "文字 · 虚构示例" }
];
const list = document.getElementById("demo-list");
const detail = document.getElementById("demo-detail");
const search = document.getElementById("demo-search");
let activeFilter = "all";
let selectedID = "paper";
let visible = [];
function element(tag, className, text) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined) node.textContent = text;
  return node;
}
function render() {
  const terms = search.value.toLocaleLowerCase().trim().split(/\s+/).filter(Boolean);
  visible = examples.filter(item => {
    const typeMatch = activeFilter === "all" || (activeFilter === "text" && item.kind !== "image") ||
      (activeFilter === "image" && item.kind === "image") || (activeFilter === "favorite" && item.favorite);
    const content = `${item.title} ${item.text} ${item.source}`.toLocaleLowerCase();
    return typeMatch && terms.every(term => content.includes(term));
  });
  if (!visible.some(item => item.id === selectedID)) selectedID = visible[0]?.id;
  list.replaceChildren();
  document.getElementById("demo-count").textContent = `${visible.length} 条`;
  for (const item of visible) {
    const row = element("button", "demo-row");
    row.type = "button";
    row.setAttribute("aria-pressed", String(item.id === selectedID));
    row.setAttribute("aria-label", `${item.title}，${item.source}`);
    const thumb = element("span", "demo-thumb", item.kind === "image" ? undefined : item.kind === "link" ? "↗" : "≡");
    if (item.kind === "image") {
      const image = element("img");
      image.src = "assets/hero-art.jpg";
      image.alt = "";
      thumb.append(image);
    }
    const copy = element("span", "demo-row-copy");
    copy.append(element("span", "demo-row-title", item.title), element("span", "demo-row-meta", `${item.source} · ${item.time}`));
    row.append(thumb, copy, element("span", "row-star", item.favorite ? "★" : "☆"));
    row.addEventListener("click", () => { selectedID = item.id; render(); });
    list.append(row);
  }
  detail.replaceChildren();
  const selected = visible.find(item => item.id === selectedID);
  if (!selected) {
    list.append(element("div", "demo-empty", "没有匹配的示例\n试试其他关键词"));
    detail.append(element("div", "demo-empty", "这是一个本地示例演示\n不会读取你的剪贴板"));
    return;
  }
  const toolbar = element("div", "preview-toolbar");
  toolbar.append(element("span", null, selected.kind === "image" ? "图片预览" : selected.kind === "link" ? "链接" : "文字"));
  const star = element("button", null, selected.favorite ? "★" : "☆");
  star.type = "button";
  star.setAttribute("aria-label", selected.favorite ? "取消收藏此示例" : "收藏此示例");
  star.addEventListener("click", () => { selected.favorite = !selected.favorite; render(); });
  toolbar.append(star);
  detail.append(toolbar);
  if (selected.kind === "image") {
    const art = element("img", "demo-preview-art");
    art.src = "assets/hero-art.jpg";
    art.alt = "GPT 生成的象牙白与青绿色折纸雕塑";
    detail.append(art);
  } else detail.append(element("div", "preview-text", selected.text));
  detail.append(element("p", "preview-title", selected.title), element("p", "preview-meta", selected.meta));
}
search.addEventListener("input", render);
search.addEventListener("keydown", event => {
  if (!event.isComposing && (event.key === "ArrowDown" || event.key === "ArrowUp")) {
    event.preventDefault();
    const index = visible.findIndex(item => item.id === selectedID);
    selectedID = visible[Math.max(0, Math.min(visible.length - 1, index + (event.key === "ArrowDown" ? 1 : -1)))]?.id;
    render();
  }
});
const tabs = [...document.querySelectorAll("[data-filter]")];
function activateTab(tab) {
  activeFilter = tab.dataset.filter;
  tabs.forEach(button => { button.setAttribute("aria-selected", String(button === tab)); button.tabIndex = button === tab ? 0 : -1; });
  render();
}
tabs.forEach((tab, index) => {
  tab.tabIndex = index === 0 ? 0 : -1;
  tab.addEventListener("click", () => activateTab(tab));
  tab.addEventListener("keydown", event => {
    let next;
    if (event.key === "ArrowRight") next = (index + 1) % tabs.length;
    if (event.key === "ArrowLeft") next = (index + tabs.length - 1) % tabs.length;
    if (event.key === "Home") next = 0;
    if (event.key === "End") next = tabs.length - 1;
    if (next !== undefined) { event.preventDefault(); activateTab(tabs[next]); tabs[next].focus(); }
  });
});
render();
