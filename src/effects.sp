
stock DG_Effects_CreateDeathEffect(ent, val) {
	if (GetConVarBool(dgBottleDeath)) {
		new Handle:datapack;
		CreateDataTimer(0.1, DG_Effects_SpawnDeathEffect, datapack);
		WritePackCell(datapack, ent);
		WritePackCell(datapack, val);
	}
}

public Action:DG_Effects_SpawnDeathEffect(Handle:timer, Handle:data) {
	ResetPack(data);
	new client = ReadPackCell(data);
	new amount = ReadPackCell(data);
	if (amount < 0) amount = 0;

	if (GetConVarBool(dgHolidayMode)) {
		amount = amount * 2;
	}
	for (new i = 0; i < amount; i++) {
		//Create the random angle/velocities of each bottle, based on adding to players velocity
		new Float:vel[3];
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel)
		ScaleVector(vel, 1.8);
		vel[0] += GetRandomFloat(-150.0, 150.0);
		vel[1] += GetRandomFloat(-150.0, 150.0);
		vel[2] += GetRandomFloat(-30.0, 90.0);
		DG_Effects_SpawnBottleAtClient(client, vel);
	}
}

stock DG_Effects_SpawnBottleAtClient(client, Float:avel[3]) {
	if (GetEntityCount() + 5 > GetMaxEntities()) {
		return; //Prevent crashing server by creating too many entities
	}
	new ent = CreateEntityByName("prop_physics_override");
	//Create the random angle/velocities of each bottle, based on adding to players velocity
	new Float:cvel[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", cvel)

	new Float:vel[3];
	AddVectors(cvel, avel, vel);

	new Float:pos[3];
	//GetEntPropVector(client, Prop_Data, "m_vecOrigin", pos)
	GetClientEyePosition(client, pos);

	new Float:ang[3];
	ang[0] = GetRandomFloat(0.0, 359.0);
	ang[1] = GetRandomFloat(0.0, 359.0);
	ang[2] = GetRandomFloat(0.0, 359.0);

	new String:modelName[100];
	modelName = "models/props_gameplay/bottle001.mdl";
	if (GetConVarBool(dgHolidayMode)) {
		new rand = GetRandomInt(0,6);
		if (rand == 1) {
			modelName = "models/player/items/all_class/oh_xmas_tree_soldier.mdl";
		}
		else if (rand == 2) {
			modelName = "models/weapons/c_models/c_candy_cane/c_candy_cane.mdl";
		}
		else if (rand == 3) {
			modelName = "models/player/items/engineer/engineer_colored_lights.mdl";
		}
	}

	DispatchKeyValue(ent,"damagetoenablemotion","0");
	DispatchKeyValue(ent,"forcetoenablemotion","0");
	DispatchKeyValue(ent,"Damagetype","0");
	DispatchKeyValue(ent,"disablereceiveshadows","1");
	//DispatchKeyValue(ent,"massScale","0");
	DispatchKeyValue(ent,"nodamageforces","0");
	DispatchKeyValue(ent,"shadowcastdist","0");
	DispatchKeyValue(ent,"physdamagescale", "0.0");
	DispatchKeyValue(ent,"disableshadows","1");
	DispatchKeyValue(ent,"physicsmode","3");
	DispatchKeyValue(ent,"spawnflags","4");
	DispatchKeyValue(ent,"model", modelName);
	DispatchKeyValueFloat(ent,"modelscale",GetRandomFloat(0.8,1.2));
	DispatchSpawn(ent);
	TeleportEntity(ent, pos, ang, vel);
	SetEntityMoveType(ent, MOVETYPE_VPHYSICS);
	CreateTimer(12.0, DG_Effects_DestroyDeathEffect, ent);
}

public Action:DG_Effects_DestroyDeathEffect(Handle:timer, any:ent) {
	if (IsValidEntity(ent)) {
		//Make sure this is the entity we're expecting
		new String:classname[256];
		GetEntityClassname(ent, classname, sizeof(classname));
		if (StrContains(classname, "prop_physics_override")) {
			AcceptEntityInput(ent, "kill");
		}
	}
}

stock DG_Effects_CreateSprite(iClient, String:sprite[])
{
	//Clean up any existing sprites and their parents:
	if (dgSprites[iClient] > 0 || dgSpritesParents[iClient] > 0) {
		DG_Effects_KillSprite(iClient);
	}

	//new String:strClient[64];
	//Format(strClient, sizeof(strClient), "client%i", iClient);
	//DispatchKeyValue(iClient, "targetname", strClient);


	new String:strParent[64];
	Format(strParent, sizeof(strParent), "prop%i", iClient);
	new parent = CreateEntityByName("prop_dynamic");
	DispatchKeyValue(parent, "targetname", strParent);
	//DispatchKeyValue(parent, "parentname", strClient);

	//Special values given by couch do reduce strain on server

	DispatchKeyValue(parent,"renderfx","0");
	DispatchKeyValue(parent,"damagetoenablemotion","0");
	DispatchKeyValue(parent,"forcetoenablemotion","0");
	DispatchKeyValue(parent,"Damagetype","0");
	DispatchKeyValue(parent,"disablereceiveshadows","1");
	DispatchKeyValue(parent,"massScale","0");
	DispatchKeyValue(parent,"nodamageforces","0");
	DispatchKeyValue(parent,"shadowcastdist","0");
	DispatchKeyValue(parent,"disableshadows","1");
	DispatchKeyValue(parent,"spawnflags","1670");
	DispatchKeyValue(parent,"model","models/player/medic_animations.mdl");
	DispatchKeyValue(parent,"PerformanceMode","1");
	DispatchKeyValue(parent,"rendermode","10");
	DispatchKeyValue(parent,"physdamagescale","0");
	DispatchKeyValue(parent,"physicsmode","2");

	DispatchSpawn(parent);

	//SetVariantString(strClient);
	//AcceptEntityInput(parent, "SetParent",parent, parent, 0);

	dgSpritesParents[iClient] = parent;

	new ent = CreateEntityByName("env_sprite_oriented");

	if (ent)
	{
		new String:StrEntityName[64]; Format(StrEntityName, sizeof(StrEntityName), "ent_sprite_oriented_%i", ent);
		DispatchKeyValue(ent, "model", sprite);

		DispatchKeyValue(ent, "classname", "env_sprite_oriented");
		DispatchKeyValue(ent, "spawnflags", "1");
		DispatchKeyValue(ent, "scale", "0.1");
		DispatchKeyValue(ent, "rendermode", "1");
		DispatchKeyValue(ent, "rendercolor", "255 255 255");
		DispatchKeyValue(ent, "targetname", StrEntityName);
		DispatchKeyValue(ent, "parentname", strParent);

		DispatchSpawn(ent);
		//TeleportEntity(ent, vOrigin, NULL_VECTOR, NULL_VECTOR);
		dgSprites[iClient] = ent;

		SetVariantString(strParent);
		AcceptEntityInput(ent, "SetParent");

		SDKHook(ent, SDKHook_SetTransmit, SetTransmit);
	}
}

stock DG_Effects_KillSprite(iClient)
{
	if (dgSprites[iClient] > 0 && IsValidEntity(dgSprites[iClient]))
	{
		AcceptEntityInput(dgSprites[iClient], "kill");
		dgSprites[iClient] = 0;
	}

	if (dgSpritesParents[iClient] > 0 && IsValidEntity(dgSpritesParents[iClient]))
	{
		AcceptEntityInput(dgSpritesParents[iClient], "kill");
		dgSpritesParents[iClient] = 0;
	}
}

public DG_Effects_KillAllSprites() {
	for(new i = 1; i <= MaxClients; i++)
	{
		DG_Effects_KillSprite(i);
	}
}