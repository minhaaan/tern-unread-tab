--!strict
-- 안 보던 탭에서 에이전트 턴이 끝나면 탭을 주황으로 칠하고, 그 탭을 열면 원래 색으로 되돌린다.
-- 칠하기 전 색은 tern.kv에 "tab:<id>" → 색 이름(없으면 "")으로 둔다. 재시작·리로드 뒤에도 되돌릴 수 있게.

local UNREAD: TabColor = "orange"

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

tern.on("agent_finished", function(ev: AgentFinishedEvent, cx: WindowCx)
	if ev.result ~= "done" and ev.result ~= "failed" then
		return
	end
	local tab = cx.session:tab_of(ev.pane)
	if tab == nil or tern.kv.get(key(tab)) ~= nil then
		return
	end
	local focused = cx.session:focused()
	if focused ~= nil and cx.session:tab_of(focused) == tab then
		return
	end
	tern.kv.set(key(tab), color_of(cx, tab) or "")
	cx.layout:color_tab(tab, UNREAD)
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
