import { App } from "aws-cdk-lib";
import { Cluster } from "./shared/cluster";
import { UsdxlCronyield } from "./cronyield";

const app = new App();

const cluster = new Cluster(app, "imported-usdxl-cronyield-cluster", {
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT,
    region: process.env.CDK_DEFAULT_REGION,
  },
});

new UsdxlCronyield(app, "usdxl-cronyield", {
  cluster: cluster.cluster,
  vpc: cluster.vpc,
  policies: {},
});
