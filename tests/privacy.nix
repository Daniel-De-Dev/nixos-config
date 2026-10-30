{ lib, modules }:
let
  mapPrivacy = import ../lib/privacy.nix { inherit lib; };
  fixture = import ./fixtures/privacy/data.nix;
  operatorModule =
    (import ../modules/core/operator.nix { }).flake.nixosModules.core-operator;

  profileFixture = {
    global = {
      operator.email = "global@example.invalid";
      keyMap = "us";
      ssh = {
        authorizedKeys = [ "global-key" ];
        matchBlocks."github.com".identityFile = "~/.ssh/id_ed25519_git";
      };
    };
    profiles = {
      university = {
        operator.email = "university@example.invalid";
        keyMap = "no";
        ssh = {
          authorizedKeys = [ "university-key" ];
          matchBlocks.cluster.hostname = "cluster.example.invalid";
        };
      };
      travel = {
        operator.email = "travel@example.invalid";
        ssh.authorizedKeys = [ "travel-key" ];
      };
    };
    hosts.box-01 = {
      profiles = [
        "university"
        "travel"
      ];
      hostName = "profile-host";
    };
  };

  schema = lib.evalModules {
    class = "nixos";
    modules = [ modules.core-identity ];
  };

  evaluate =
    {
      data ? { },
      machine ? "box-01",
      overrides ? { },
    }:
    (lib.evalModules {
      class = "nixos";
      modules = [
        modules.core-identity
        { my = mapPrivacy { inherit data machine; }; }
        { my = overrides; }
      ];
    }).config.my;

  evaluateInput =
    args:
    (lib.evalModules {
      class = "nixos";
      specialArgs = {
        inputs = { };
        machine = "box-01";
      }
      // args;
      modules = [ modules.core-privacy ];
    }).config.my;

  fails = value: !(builtins.tryEval (builtins.deepSeq value true)).success;

  operatorAccepts =
    my:
    lib.all (entry: entry.assertion)
      (operatorModule {
        inherit lib;
        config = {
          inherit my;
          services.openssh = {
            enable = true;
            settings.PasswordAuthentication = false;
          };
        };
      }).config.assertions;

  invalidGroups = lib.listToAttrs (
    map
      (name: {
        name = "testInvalidGroup-${name}";
        value = {
          expr = fails (evaluate {
            data.global.${name} = "invalid";
          });
          expected = true;
        };
      })
      [
        "operator"
        "locale"
        "network"
        "ssh"
        "security"
      ]
  );
in
lib.runTests (
  invalidGroups
  // {
    testSchemaNeedsNoPrivacyInput = {
      expr = {
        inherit (schema.config.my.operator) username hashedPassword email;
        inherit (schema.config.my.host)
          name
          id
          timeZone
          keyMap
          ;
      };
      expected = {
        username = "operator";
        hashedPassword = "!";
        email = "operator@localhost";
        name = "nixos";
        id = "00000000";
        timeZone = "UTC";
        keyMap = "us";
      };
    };

    testRawBusIsNotAnOption = {
      expr = schema.options.my ? privacy;
      expected = false;
    };

    testMissingInputUsesDefaults = {
      expr = (evaluateInput { }).host.name;
      expected = "box-01";
    };

    testNullInputUsesDefaults = {
      expr = (evaluateInput { inputs.privacy = null; }).operator.username;
      expected = "operator";
    };

    testAdapterNeedsNoMachineArgument = {
      expr =
        (lib.evalModules {
          class = "nixos";
          specialArgs.inputs = { };
          modules = [ modules.core-privacy ];
        }).config.my.host.name;
      expected = "nixos";
    };

    testInputDirectoryMustContainData = {
      expr = fails (evaluateInput {
        inputs.privacy = ./fixtures;
      });
      expected = true;
    };

    testPublicFixtureThroughAdapter = {
      expr =
        let
          my = evaluateInput { inputs.privacy = ./fixtures/privacy; };
        in
        {
          inherit (my.operator) username email hashedPassword;
          inherit (my.host) name id;
        };
      expected = {
        username = "fixture-operator";
        email = "operator@example.invalid";
        hashedPassword = "*";
        name = "box-01";
        id = "11111111";
      };
    };

    testSecondHostGetsItsOwnData = {
      expr =
        (evaluate {
          data = fixture;
          machine = "box-02";
        }).host.id;
      expected = "22222222";
    };

    testNoMachineUsesGlobalData = {
      expr =
        (evaluate {
          machine = null;
          data.global.operator.username = "global-operator";
        }).operator.username;
      expected = "global-operator";
    };

    testNoMachineHasValidHostnameDefault = {
      expr = (evaluate { machine = null; }).host.name;
      expected = "nixos";
    };

    testUnknownHostKeepsGlobalData = {
      expr =
        (evaluate {
          data = fixture;
          machine = "unknown-host";
        }).operator.email;
      expected = "operator@example.invalid";
    };

    testExplicitHostnameWinsOverMachineKey = {
      expr = (evaluate { data.global.hostName = "custom-host"; }).host.name;
      expected = "custom-host";
    };

    testNestedHostOverridePreservesOtherFields = {
      expr =
        let
          my = evaluate {
            data = lib.recursiveUpdate fixture {
              hosts.box-01.operator.email = "host@example.invalid";
            };
          };
        in
        {
          inherit (my.operator) email fullName;
        };
      expected = {
        email = "host@example.invalid";
        fullName = "Evaluation Operator";
      };
    };

    testHostListReplacesGlobalList = {
      expr =
        (evaluate {
          data = {
            global.ssh.authorizedKeys = [ "global-key" ];
            hosts.box-01.ssh.authorizedKeys = [ "host-key" ];
          };
        }).host.ssh.authorizedKeys;
      expected = [ "host-key" ];
    };

    testSelectedProfilesApplyInListedOrder = {
      expr =
        let
          my = evaluate { data = profileFixture; };
        in
        {
          inherit (my.operator) email;
          inherit (my.host) name keyMap;
          inherit (my.host.ssh) authorizedKeys;
        };
      expected = {
        email = "travel@example.invalid";
        name = "profile-host";
        keyMap = "no";
        authorizedKeys = [ "travel-key" ];
      };
    };

    testReversingProfileOrderChangesPrecedence = {
      expr =
        (evaluate {
          data = lib.recursiveUpdate profileFixture {
            hosts.box-01.profiles = [
              "travel"
              "university"
            ];
          };
        }).operator.email;
      expected = "university@example.invalid";
    };

    testProfilesRecursivelyPreserveGlobalSshRoutes = {
      expr = (evaluate { data = profileFixture; }).host.ssh.matchBlocks;
      expected = {
        "github.com".identityFile = "~/.ssh/id_ed25519_git";
        cluster.hostname = "cluster.example.invalid";
      };
    };

    testHostWinsOverSelectedProfiles = {
      expr =
        let
          my = evaluate {
            data = lib.recursiveUpdate profileFixture {
              hosts.box-01 = {
                operator.email = "host@example.invalid";
                ssh.authorizedKeys = [ ];
              };
            };
          };
        in
        {
          inherit (my.operator) email;
          inherit (my.host.ssh) authorizedKeys;
        };
      expected = {
        email = "host@example.invalid";
        authorizedKeys = [ ];
      };
    };

    testHostWithoutProfileSelectionUsesOnlyGlobalData = {
      expr =
        let
          my = evaluate {
            data = profileFixture;
            machine = "box-02";
          };
        in
        {
          inherit (my.operator) email;
          inherit (my.host.ssh) authorizedKeys;
        };
      expected = {
        email = "global@example.invalid";
        authorizedKeys = [ "global-key" ];
      };
    };

    testExplicitConfigurationOverridesProfileDefault = {
      expr =
        (evaluate {
          data = profileFixture;
          overrides.operator.email = "configured@example.invalid";
        }).operator.email;
      expected = "configured@example.invalid";
    };

    testProfileSelectionDoesNotEnterTypedApi = {
      expr = (evaluate { data = profileFixture; }).host ? profiles;
      expected = false;
    };

    testUnknownProfileIsRejected = {
      expr = fails (evaluate {
        data.hosts.box-01.profiles = [ "missing" ];
      });
      expected = true;
    };

    testProfileSelectionMustBeAListOfNames = {
      expr =
        map
          (
            selection:
            fails (evaluate {
              data.hosts.box-01.profiles = selection;
            })
          )
          [
            "university"
            null
            [ 42 ]
            [ "" ]
          ];
      expected = lib.replicate 4 true;
    };

    testProfilesMustBeAnAttributeSet = {
      expr = fails (evaluate {
        data.profiles = [ ];
      });
      expected = true;
    };

    testSelectedProfileMustBeAnAttributeSet = {
      expr = fails (evaluate {
        data = {
          profiles.broken = "invalid";
          hosts.box-01.profiles = [ "broken" ];
        };
      });
      expected = true;
    };

    testSelectedProfileValuesUseTheExistingSchema = {
      expr = fails (evaluate {
        data = {
          profiles.broken.ssh.authorizedKeys = "invalid";
          hosts.box-01.profiles = [ "broken" ];
        };
      });
      expected = true;
    };

    testHostConfigurationOverridesPrivateDefault = {
      expr =
        (evaluate {
          data = fixture;
          overrides.operator.email = "configured@example.invalid";
        }).operator.email;
      expected = "configured@example.invalid";
    };

    testProfileDefaultOverridesSchemaFallback = {
      expr =
        (evaluate { overrides.operator.fullName = lib.mkDefault "Profile Operator"; })
        .operator.fullName;
      expected = "Profile Operator";
    };

    testGlobalLocaleMappingIsPreserved = {
      expr =
        (evaluate {
          data.global.locale = {
            default = "en_GB.UTF-8";
            measurement = "nb_NO.UTF-8";
          };
        }).operator.locale;
      expected = {
        default = "en_GB.UTF-8";
        measurement = "nb_NO.UTF-8";
      };
    };

    testAllSupportedFieldsAreMapped = {
      expr = evaluate {
        data.global = {
          operator = {
            username = "mapped-operator";
            hashedPassword = "*";
            sshKeys = [ "operator-key" ];
            fullName = "Mapped Operator";
            email = "mapped@example.invalid";
            signingKey = "~/.ssh/mapped.pub";
          };
          locale = {
            default = "en_GB.UTF-8";
            measurement = "nb_NO.UTF-8";
          };
          hostName = "mapped-host";
          hostId = "1234abcd";
          timeZone = "Europe/Oslo";
          keyMap = "no";
          network.macRandomize = true;
          ssh = {
            authorizedKeys = [ "host-key" ];
            matchBlocks.example.hostname = "example.invalid";
          };
          security = {
            usbguard = true;
            strictKernel = false;
            kernelLockdown = "confidentiality";
          };
        };
      };
      expected = {
        operator = {
          username = "mapped-operator";
          hashedPassword = "*";
          sshKeys = [ "operator-key" ];
          fullName = "Mapped Operator";
          email = "mapped@example.invalid";
          signingKey = "~/.ssh/mapped.pub";
          locale = {
            default = "en_GB.UTF-8";
            measurement = "nb_NO.UTF-8";
          };
        };
        host = {
          name = "mapped-host";
          id = "1234abcd";
          timeZone = "Europe/Oslo";
          keyMap = "no";
          network = {
            macRandomize = true;
            vpnProfiles = { };
          };
          ssh = {
            authorizedKeys = [ "host-key" ];
            matchBlocks.example.hostname = "example.invalid";
          };
          security = {
            usbguard = true;
            strictKernel = false;
            kernelLockdown = "confidentiality";
          };
        };
      };
    };

    testUnknownMetadataDoesNotEnterTypedApi = {
      expr =
        (evaluate { data.global.extraMetadata = "ignored"; }).host ? extraMetadata;
      expected = false;
    };

    testVpnProfilesDefaultToEmpty = {
      expr = (evaluate { }).host.network.vpnProfiles;
      expected = { };
    };

    testVpnProfileFromPrivateInput = {
      expr =
        (evaluateInput { inputs.privacy = ./fixtures/privacy; })
        .host.network.vpnProfiles.example-vpn;
      expected = {
        gateway = "vpn.example.invalid/private";
        protocol = "anyconnect";
        authGroup = "private";
        userAgent = "AnyConnect";
        mtu = 1200;
        dnsSearch = [ "~example.invalid" ];
      };
    };

    testHostVpnOverridePreservesProfileFields = {
      expr =
        let
          my = evaluate {
            data = lib.recursiveUpdate fixture {
              hosts.box-01.network.vpnProfiles.example-vpn.gateway = "other.example.invalid";
            };
          };
        in
        {
          inherit (my.host.network.vpnProfiles.example-vpn) gateway mtu;
        };
      expected = {
        gateway = "other.example.invalid";
        mtu = 1200;
      };
    };

    testVpnRejectsInvalidMtu = {
      expr = fails (evaluate {
        data.global.network.vpnProfiles.invalid = {
          gateway = "vpn.example.invalid";
          mtu = "1200";
        };
      });
      expected = true;
    };

    testRootMustBeAnAttributeSet = {
      expr = fails (evaluate {
        data = [ ];
      });
      expected = true;
    };

    testGlobalMustBeAnAttributeSet = {
      expr = fails (evaluate {
        data.global = [ ];
      });
      expected = true;
    };

    testHostsMustBeAnAttributeSet = {
      expr = fails (evaluate {
        data.hosts = [ ];
      });
      expected = true;
    };

    testSelectedHostMustBeAnAttributeSet = {
      expr = fails (evaluate {
        data.hosts.box-01 = [ ];
      });
      expected = true;
    };

    testTypedBooleanRejectsString = {
      expr = fails (evaluate {
        data.global.network.macRandomize = "yes";
      });
      expected = true;
    };

    testKernelLockdownDefaultsToNone = {
      expr = (evaluate { }).host.security.kernelLockdown;
      expected = "none";
    };

    testKernelLockdownRejectsUnknownMode = {
      expr = fails (evaluate {
        data.global.security.kernelLockdown = "off";
      });
      expected = true;
    };

    testTypedUsernameRejectsNumber = {
      expr = fails (evaluate {
        data.global.operator.username = 42;
      });
      expected = true;
    };

    testTypedKeysRejectScalar = {
      expr = fails (evaluate {
        data.global.ssh.authorizedKeys = "key";
      });
      expected = true;
    };

    testHostIdRejectsWrongWidth = {
      expr = fails (evaluate {
        data.global.hostId = "123";
      });
      expected = true;
    };

    testHostIdRejectsNonHexadecimalCharacters = {
      expr = fails (evaluate {
        data.global.hostId = "gggggggg";
      });
      expected = true;
    };

    testHostIdAcceptsUppercaseHexadecimal = {
      expr = (evaluate { data.global.hostId = "ABCDEF01"; }).host.id;
      expected = "ABCDEF01";
    };

    testMissingPasswordFailsOperatorAssertion = {
      expr = operatorAccepts (evaluate {
        data.global.ssh.authorizedKeys = fixture.profiles.evaluation.ssh.authorizedKeys;
      });
      expected = false;
    };

    testMissingSshKeysFailsOperatorAssertion = {
      expr = operatorAccepts (evaluate {
        data.global.operator.hashedPassword = "*";
      });
      expected = false;
    };

    testExplicitFixtureSatisfiesOperatorAssertions = {
      expr = operatorAccepts (evaluate {
        data = fixture;
      });
      expected = true;
    };
  }
)
