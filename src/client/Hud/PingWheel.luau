--!strict
-- Roda ping kontekstual (PRD §7).
--
-- PRD §7: "Roda dengan 6-8 frasa yang berubah sesuai role dan situasi."
-- PRD §2 (pilar 2): "Komunikasi tanpa mengetik. Cukup sentuh, tidak harus
-- ketik." Karena itu roda ini adalah kontrol utama, bukan pelengkap -- tiap
-- tombolnya adalah target sentuh besar (PRD §15: "Kontrol touch-first, target
-- sentuh besar").
--
-- Daftar frasa itu sendiri ada di `shared/PingPhrases.luau`, dipakai bersama
-- dengan server yang memvalidasi ID frasa yang masuk.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PingPhrases = require(Shared.PingPhrases)

local PingWheel = {}

local RADIUS = 150
local BUTTON_SIZE = 92

-- Membangun roda. `onSelect` menerima id frasa; roda tidak tahu apa pun soal
-- jaringan.
function PingWheel.mount(parent: Instance, role: string, onSelect: (string) -> ()): Frame
	local phrases = PingPhrases.forRole(role)

	local holder = Instance.new("Frame")
	holder.Name = "PingWheel"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(RADIUS * 2 + BUTTON_SIZE, RADIUS * 2 + BUTTON_SIZE)
	holder.BackgroundTransparency = 1
	holder.Visible = false
	holder.ZIndex = 10
	holder.Parent = parent

	local count = math.max(#phrases, 1)
	for index, phrase in phrases do
		-- Sebar merata mulai dari atas, searah jarum jam.
		local angle = (index - 1) / count * math.pi * 2 - math.pi / 2

		local button = Instance.new("TextButton")
		button.Name = phrase.id
		button.Text = phrase.label
		button.TextSize = 16
		button.TextWrapped = true
		button.TextColor3 = Color3.fromRGB(240, 236, 228)
		button.BackgroundColor3 = Color3.fromRGB(38, 34, 30)
		button.BorderSizePixel = 0
		button.AutoButtonColor = true
		button.AnchorPoint = Vector2.new(0.5, 0.5)
		button.Position = UDim2.new(0.5, math.cos(angle) * RADIUS, 0.5, math.sin(angle) * RADIUS)
		button.Size = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE)
		button.ZIndex = 11

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = button

		button.Activated:Connect(function()
			onSelect(phrase.id)
			holder.Visible = false
		end)

		button.Parent = holder
	end

	return holder
end

return PingWheel
