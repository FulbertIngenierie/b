//-----------------------------------------------------------------------------
// Torque
// Copyright GarageGames, LLC 2011
//-----------------------------------------------------------------------------

// This is the default save location for any Decal datablocks created in the
// Decal Editor (this script is executed from onServerCreated())

datablock DecalData(ScorchBigDecal)
{
   Material = "DECAL_scorch";
   size = "5.0";
   lifeSpan = "50000";
};

datablock DecalData(ScorchRXDecal)
{
   Material = "DECAL_RocketEXP";
   size = "5.0";
   lifeSpan = "50000";
   randomize = "1";
   texRows = "2";
   texCols = "2";
   clippingAngle = "60";
   textureCoordCount = "3";
   textureCoords[0] = "0 0 0.5 0.5";
   textureCoords[1] = "0.5 0 0.5 0.5";
   textureCoords[2] = "0 0.5 0.5 0.5";
   textureCoords[3] = "0.5 0.5 0.5 0.5";
};

datablock DecalData(BulletHoleDecal)
{
   Material = "DECAL_BulletHole";
   size = "0.1";
   lifeSpan = "50000";
   randomize = "1";
   texRows = "2";
   texCols = "2";
   clippingAngle = "60";
   textureCoordCount = "3";
   textureCoords[0] = "0 0 0.5 0.5";
   textureCoords[1] = "0.5 0 0.5 0.5";
   textureCoords[2] = "0 0.5 0.5 0.5";
   textureCoords[3] = "0.5 0.5 0.5 0.5";
};

//datablock DecalData(SedimentDecal01)
//{
//   Material = "DECAL_sediment_01";
//   textureCoordCount = "0";
//};

//datablock DecalData(LeavesTwigsDecal)
//{
//   Material = "DECAL_leaves_01";
//   textureCoordCount = "0";
//   randomize = "1";
//};

//datablock DecalData(RockyCliffDecal)
//{
//   Material = "DECAL_cliff_rocks_01";
//   textureCoordCount = "0";
//};


