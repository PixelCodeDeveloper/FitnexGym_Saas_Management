const express = require("express");
const deviceRoutes = require("./routes/device");
const peopleRoutes = require("./routes/people");
const recordRoutes = require("./routes/records");
const { TEST_GYM_ID } = require("./supabase");

// A3-8396 / FC-8200H series ka HTTPv2 protocol — device khud client hai,
// hume koi local Windows/IIS/MSSQL nahi chahiye, sirf ye REST endpoints chahiye.
// Isolated app + alag port — purane device-server (server.js) ko bilkul touch nahi karta.
function start(port) {
  const app = express();
  app.use(express.json({ limit: "5mb" }));

  app.use("/Device", deviceRoutes);
  app.use("/People", peopleRoutes);
  app.use("/Record", recordRoutes);

  app.get("/health", (req, res) => res.json({ status: "ok", module: "httpv2-a3-8396", testGym: TEST_GYM_ID }));

  app.listen(port, "0.0.0.0", () => {
    console.log("════════════════════════════════════════");
    console.log(" Gym Device Server — V2 (A3-8396 HTTPv2)");
    console.log("════════════════════════════════════════");
    console.log(` Port        : ${port}  ← naya device isko HTTPClient_ServerAddr mein daale`);
    console.log(` Scope       : Bhrambhrastra GYM (test gym) ONLY — ${TEST_GYM_ID}`);
    console.log(` Routes      : Device/*, People/* (incl. PushPeople), Record/*`);
    console.log("════════════════════════════════════════");
  });
}

module.exports = { start };
