--!strict
-- 에이전트가 일하는 탭은 이름 앞에 도는 링, 입력을 기다리는 탭은 "?"를 붙인다.
-- 안 보던 탭에서 턴이 끝나면 주황, 입력을 기다리면 빨강으로 칠하고, 그 탭을 열면 원래 색으로 되돌린다.
-- 칠하기 전 색은 tern.kv에 "tab:<id>" → 색 이름(없으면 "")으로 둔다. 재시작·리로드 뒤에도 되돌릴 수 있게.

local UNREAD: TabColor = "orange"
local WAITING: TabColor = "red"

-- Tern은 에이전트가 일하는 탭 버튼에 `.working`을 단다. 이름(.nm)은 글자색이 투명(효과용)이라 링 색을 따로 준다.
tern.css(
	"spinner",
	[[
@keyframes unread-tab-spin { to { transform: rotate(360deg); } }
nav#tabbar button.kit-tab.working > span.tx > span.nm::before {
	content: "";
	display: inline-block;
	box-sizing: border-box;
	width: 0.85em;
	height: 0.85em;
	margin-right: 0.4em;
	vertical-align: -0.1em;
	border: 2px solid rgba(140, 170, 255, 0.25);
	border-top-color: rgb(140, 170, 255);
	border-radius: 50%;
	animation: unread-tab-spin 0.8s linear infinite;
}
]]
)

local waiting: { [number]: boolean } = {}
local waiting_tabs: { [number]: boolean } = {}

local function key(tab: number): string
	return "tab:" .. tostring(tab)
end

local function color_of(cx: WindowCx, tab: number): TabColor?
	for _, t in cx.session:tabs() do
		if t.id == tab then
			return t.color
		end
	end
	return nil
end

local function is_focused_tab(cx: WindowCx, tab: number): boolean
	local focused = cx.session:focused()
	return focused ~= nil and cx.session:tab_of(focused) == tab
end

-- 원래 색은 처음 칠할 때만 저장한다. 주황 위에 빨강을 덧칠해도 되돌릴 색은 그대로.
local function paint(cx: WindowCx, tab: number, color: TabColor)
	if tern.kv.get(key(tab)) == nil then
		tern.kv.set(key(tab), color_of(cx, tab) or "")
	end
	cx.layout:color_tab(tab, color)
end

local function recompute(cx: WindowCx)
	local next: { [number]: boolean } = {}
	for pane in waiting do
		local tab = cx.session:tab_of(pane)
		if tab ~= nil then
			next[tab] = true
		end
	end
	waiting_tabs = next
	tern.chrome.refresh()
end

tern.chrome.tab_title(function(tab: TabInfo): string?
	if not waiting_tabs[tab.id] then
		return nil
	end
	local base = if tab.name ~= nil and tab.name ~= "" then tab.name else tab.title
	if base == "" then
		base = tab.program
	end
	return "? " .. base
end)

tern.timer(0, function(cx: WindowCx?)
	if cx == nil then
		return
	end
	for _, agent in cx.agents:list() do
		if agent.state == "waiting_input" then
			waiting[agent.pane] = true
		end
	end
	recompute(cx)
end)

tern.on("agent_state", function(ev: AgentStateEvent, cx: WindowCx)
	local was = waiting[ev.pane] == true
	local now = ev.new == "waiting_input"
	if was == now then
		return
	end
	waiting[ev.pane] = if now then true else nil
	if now then
		local tab = cx.session:tab_of(ev.pane)
		if tab ~= nil and not is_focused_tab(cx, tab) then
			paint(cx, tab, WAITING)
		end
	end
	recompute(cx)
end)

tern.on("agent_finished", function(ev: AgentFinishedEvent, cx: WindowCx)
	if ev.result == "exited" or ev.result == "closed" then
		if waiting[ev.pane] then
			waiting[ev.pane] = nil
			recompute(cx)
		end
		return
	end
	local tab = cx.session:tab_of(ev.pane)
	if tab == nil or is_focused_tab(cx, tab) then
		return
	end
	paint(cx, tab, UNREAD)
end)

tern.on("focus", function(ev: FocusEvent, cx: WindowCx)
	local before = tern.kv.get(key(ev.tab))
	if before == nil then
		return
	end
	tern.kv.set(key(ev.tab), nil)
	cx.layout:color_tab(ev.tab, if before == "" then nil else before :: TabColor)
end)

tern.on("tab_closed", function(ev: TabEvent, _cx: WindowCx)
	tern.kv.set(key(ev.tab), nil)
end)
