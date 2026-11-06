--!strict
-- Transport boundary for the standalone Forge workbench. Inventory is server-owned.
export type Artifact = {
	UUID: string,
	TemplateId: string,
	DisplayName: string,
	Type: string,
	Rarity: number,
	Star: number,
	Locked: boolean?,
	EquippedHeroUUID: string?,
}
export type Hero = {
	Assignment: string?,
	UUID: string,
	TemplateId: string,
	DisplayName: string,
	Archetype: string,
	Stars: number,
	Level: number,
	Rarity: number?,
	QualityScalar: number?,
	AttackInterval: number?,
	ComaUntilTimestamp: number?,
	EquippedArtifactUUID: string?,
}
export type Snapshot = {
	Revision: number,
	Artifacts: { [string]: Artifact },
	Heroes: { [string]: Hero },
	Gold: number,
	Gems: number,
}
export type Filter = {
	Query: string,
	Ownership: string, -- ALL | EQUIPPED | UNEQUIPPED | HERO
	Rarity: number, -- 0 = all
	WeaponType: string, -- ALL or the catalog's type
	Sort: string, -- BEST | POWER | RARITY | STARS | NAME
}
export type Command = {
	RequestId: string,
	ExpectedRevision: number,
	Kind: string, -- EQUIP | UNEQUIP | LOCK | UPGRADE | UNDO
	ArtifactId: string?,
	HeroId: string?,
	MaterialIds: { string }?,
	Locked: boolean?,
	UndoToken: string?,
}
export type Result = {
	RequestId: string,
	Ok: boolean,
	Message: string,
	Snapshot: Snapshot,
	UndoToken: string?, -- server-issued, single use; equipment changes only
	UndoExpiresAt: number?, -- Workspace:GetServerTimeNow() timebase
}
export type Transport = {
	-- Must be idempotent by RequestId. On uncertain delivery, reconcile that SAME ID.
	Execute: (command: Command) -> Result,
	Reconcile: (requestId: string) -> Result,
}
export type Props = {
	Snapshot: Snapshot,
	Transport: Transport,
	OnClose: () -> (),
	OnSummon: () -> (), -- hand off to the existing artifact summon banner
	OnSell: (() -> ())?,
	OnSellArtifacts: ((ids: { string }) -> (boolean, string?))?,
	OnContextChanged: ((heroId: string?, artifactId: string?, mode: string) -> ())?,
	OnBusyChanged: ((busy: boolean) -> ())?,
	OnSnapshot: ((snapshot: Snapshot) -> ())?,
	InitialHeroId: string?,
	InitialArtifactId: string?,
	InitialMode: string?,
	InitialPane: ("INVENTORY" | "DETAILS" | "SELL")?,
	MaxWindowSize: Vector2?, -- default 960×640; optional expanded desktop layout
}
return {}
