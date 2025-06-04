import { IgnoreMode } from "aws-cdk-lib";
import * as ec2 from "aws-cdk-lib/aws-ec2";
import * as ecs from "aws-cdk-lib/aws-ecs";
import * as ecsPatterns from "aws-cdk-lib/aws-ecs-patterns";
import * as events from "aws-cdk-lib/aws-events";
import * as iam from "aws-cdk-lib/aws-iam";
import * as logs from "aws-cdk-lib/aws-logs";
import * as secretsmanager from "aws-cdk-lib/aws-secretsmanager";
import * as elbv2 from "aws-cdk-lib/aws-elasticloadbalancingv2";
import * as servicediscovery from "aws-cdk-lib/aws-servicediscovery";
import { Construct } from "constructs";

export type BackendProps = {
  cluster: ecs.ICluster;
  service: string;
  containerEnvironment?: { [key: string]: string };
  containerSecrets?: { [key: string]: ecs.Secret };
  inlineRolePolicies?: iam.RoleProps["inlinePolicies"];
  vpc: ec2.IVpc;
};

export class Backend extends Construct {
  public readonly scheduledTask: ecsPatterns.ScheduledFargateTask;
  public readonly role: iam.Role;

  constructor(scope: Construct, id: string, props: BackendProps) {
    super(scope, id);

    const { cluster, inlineRolePolicies = {}, vpc } = props;

    const transmitterSecret = secretsmanager.Secret.fromSecretNameV2(
      this,
      "liquidator-secret",
      "frax-liquidator/config"
    );

    // Create a security group for the scheduled task
    const taskSecurityGroup = new ec2.SecurityGroup(this, "TaskSecurityGroup", {
      vpc,
      description: "Security group for usdxl cronyield scheduled task",
      allowAllOutbound: true,
    });

    // Create role for the scheduled task
    this.role = new iam.Role(this, `${id}-role`, {
      assumedBy: new iam.ServicePrincipal("ecs-tasks.amazonaws.com"),
      managedPolicies: [
        iam.ManagedPolicy.fromAwsManagedPolicyName(
          "service-role/AmazonECSTaskExecutionRolePolicy"
        ),
      ],
      inlinePolicies: {
        ...inlineRolePolicies,
      },
    });

    // Add permission to access the secret
    this.role.addToPolicy(
      new iam.PolicyStatement({
        actions: ["secretsmanager:GetSecretValue"],
        resources: [transmitterSecret.secretArn],
      })
    );

    const image = ecs.ContainerImage.fromAsset("./", {
      file: "Dockerfile",
      buildArgs: {
        SERVICE: props.service,
      },
      ignoreMode: IgnoreMode.DOCKER,
    });

    // Create task definition with proper roles
    const taskDefinition = new ecs.FargateTaskDefinition(
      this,
      `${id}-task-def`,
      {
        memoryLimitMiB: 2048,
        cpu: 1024,
        taskRole: this.role,
        executionRole: this.role,
      }
    );

    // Add container to task definition
    taskDefinition.addContainer(`${id}-container`, {
      image: image,
      memoryLimitMiB: 2048,
      environment: {
        ...props.containerEnvironment,
        RPC_URL: "https://rpc.hyperliquid.xyz/evm",
        TOKEN_AMOUNT: "100",
        YIELD_TOKEN_ADDRESS: "0xca79db4B49f608eF54a5CB813FbEd3a6387bC645",
        YIELD_RECIPIENT: "0x9992eD1214EA2bC91B0587b37C3E03D5e2a242C1",
      },
      secrets: {
        PRIVATE_KEY: ecs.Secret.fromSecretsManager(
          transmitterSecret,
          "PRIVATE_KEY"
        ),
      },
      command: ["/bin/bash", "-c", "chmod +x /app/script.sh && /app/script.sh"],
      logging: ecs.LogDriver.awsLogs({
        streamPrefix: "usdxl-cronyield-scheduled",
        logRetention: logs.RetentionDays.ONE_WEEK,
      }),
      essential: true,
    });

    // Create scheduled Fargate task that runs once per day
    this.scheduledTask = new ecsPatterns.ScheduledFargateTask(
      this,
      `${id}-scheduled-task`,
      {
        cluster: cluster,
        scheduledFargateTaskDefinitionOptions: {
          taskDefinition: taskDefinition,
        },
        // Run once per day at 12:00 UTC
        schedule: events.Schedule.cron({
          minute: "25",
          hour: "17",
          day: "*",
          month: "*",
          year: "*",
        }),
        subnetSelection: {
          subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS,
        },
        securityGroups: [taskSecurityGroup],
        platformVersion: ecs.FargatePlatformVersion.LATEST,
      }
    );
  }
}
