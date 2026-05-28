import 'sample_models.dart';

const archimateSubSamples = <SubSample>[
  SubSample(
    name: 'Archimate keyword',
    source: '''
@startuml archimate #Technology "VPN Server" as vpnServerA <<technology-device>>
rectangle GO #lightgreen
rectangle STOP #red
rectangle WAIT #orange
@enduml
''',
  ),
  SubSample(
    name: 'Defining Junctions',
    source: '''
@startuml
!define Junction_Or circle #black
!define Junction_And circle #whitesmoke
Junction_And JunctionAnd
Junction_Or JunctionOr
archimate #Technology "VPN Server" as vpnServerA <<technology-device>>
rectangle GO #lightgreen
rectangle STOP #red
rectangle WAIT #orange
GO -up-> JunctionOr
STOP -up-> JunctionOr
STOP -down-> JunctionAnd
WAIT -down-> JunctionAnd
@enduml
''',
  ),
  SubSample(
    name: 'Insurance Claims Process',
    source: '''
@startuml
skinparam rectangle<<behavior>> {
\troundCorner 25
}
sprite \$bProcess jar:archimate/business-process
sprite \$aService jar:archimate/application-service
sprite \$aComponent jar:archimate/application-component
rectangle "Handle claim" as HC <<\$bProcess>><<behavior>> #Business
rectangle "Capture Information" as CI <<\$bProcess>><<behavior>> #Business
rectangle "Notify\\nAdditional Stakeholders" as NAS <<\$bProcess>><<behavior>> #Business
rectangle "Validate" as V <<\$bProcess>><<behavior>> #Business
rectangle "Investigate" as I <<\$bProcess>><<behavior>> #Business
rectangle "Pay" as P <<\$bProcess>><<behavior>> #Business
HC *-down- CI
HC *-down- NAS
HC *-down- V
HC *-down- I
HC *-down- P
CI -right->> NAS
NAS -right->> V
V -right->> I
I -right->> P
rectangle "Scanning" as scanning <<\$aService>><<behavior>> #Application
rectangle "Customer administration" as customerAdministration <<\$aService>><<behavior>> #Application
rectangle "Claims administration" as claimsAdministration <<\$aService>><<behavior>> #Application
rectangle Printing <<\$aService>><<behavior>> #Application
rectangle Payment <<\$aService>><<behavior>> #Application
scanning -up-> CI
customerAdministration -up-> CI
claimsAdministration -up-> NAS
claimsAdministration -up-> V
claimsAdministration -up-> I
Payment -up-> P
Printing -up-> V
Printing -up-> P
rectangle "Document\\nManagement\\nSystem" as DMS <<\$aComponent>> #Application
rectangle "General\\nCRM\\nSystem" as CRM <<\$aComponent>> #Application
rectangle "Home & Away\\nPolicy\\nAdministration" as HAPA <<\$aComponent>> #Application
rectangle "Home & Away\\nFinancial\\nAdministration" as HFPA <<\$aComponent>> #Application
DMS .up.|> scanning
DMS .up.|> Printing
CRM .up.|> customerAdministration
HAPA .up.|> claimsAdministration
HFPA .up.|> Payment
legend left
\tExample from the "Archisurance case study" (OpenGroup). See
\t====
\t<\$bProcess> :business process
\t====
\t<\$aService> : application service
\t====
\t<\$aComponent> : application component
endlegend
@enduml
''',
  ),
  SubSample(
    name: 'Simple Business Process',
    source: '''
@startuml
skinparam roundcorner 25
rectangle "Capture Information" as CI <<\$archimate/business-process>> #Business
@enduml
''',
  ),
  SubSample(
    name: 'List possible sprites',
    source: '''
@startuml
listsprite
@enduml
''',
  ),
  SubSample(
    name: 'Stakeholder Element',
    source: '''
@startuml
!include <archimate/Archimate>
Motivation_Stakeholder(StakeholderElement, "Stakeholder Description")
@enduml
''',
  ),
  SubSample(
    name: 'Business Service Element',
    source: '''
@startuml
!include <archimate/Archimate>
Business_Service(BService, "Business Service")
@enduml
''',
  ),
  SubSample(
    name: 'Composition Relationship',
    source: '''
@startuml
!include <archimate/Archimate>
Motivation_Stakeholder(StakeholderElement, "Stakeholder Description")
Business_Service(BService, "Business Service")
Rel_Composition(StakeholderElement, BService, "Description for the relationship")
@enduml
''',
  ),
  SubSample(
    name: 'Directional Relationship (Down)',
    source: '''
@startuml
!include <archimate/Archimate>
Motivation_Stakeholder(StakeholderElement, "Stakeholder Description")
Business_Service(BService, "Business Service")
Rel_Composition_Down(StakeholderElement, BService, "Description for the relationship")
@enduml
''',
  ),
  SubSample(
    name: 'All Archimate RelationTypes (Horizontal)',
    source: '''
@startuml
left to right direction
skinparam nodesep 4
!include <archimate/Archimate>
Rel_Triggering(i15, j15, Triggering)
Rel_Specialization(i14, j14, Specialization)
Rel_Serving(i13, j13, Serving)
Rel_Realization(i12, j12, Realization)
Rel_Influence(i11, j11, Influence)
Rel_Flow(i10, j10, Flow)
Rel_Composition(i9, j9, Composition)
Rel_Association_dir(i8, j8, Association_dir)
Rel_Association(i7, j7, Association)
Rel_Assignment(i6, j6, Assignment)
Rel_Aggregation(i5, j5, Aggregation)
Rel_Access_w(i4, j4, Access_w)
Rel_Access_rw(i3, j3, Access_rw)
Rel_Access_r(i2, j2, Access_r)
Rel_Access(i1, j1, Access)
@enduml
''',
  ),
  SubSample(
    name: 'ArchiMate Relationships Overview',
    source: '''
@startuml
title ArchiMate Relationships Overview
skinparam nodesep 5
<style>
interface {
\tshadowing 0
\tbackgroundcolor transparent
\tlinecolor transparent
\tFontColor transparent
}
</style>
!include <archimate/Archimate>
left to right direction
rectangle Other {
\t() i14
\t() j14
}
rectangle Dynamic {
\t() i10
\t() j10
\t() i15
\t() j15
}
rectangle Dependency {
\t() i13
\t() j13
\t() i4
\t() j4
\t() i11
\t() j11
\t() i7
\t() j7
}
rectangle Structural {
\t() i9
\t() j9
\t() i5
\t() j5
\t() i6
\t() j6
\t() i12
\t() j12
}
Rel_Triggering(i15, j15, Triggering)
Rel_Specialization(i14, j14, Specialization)
Rel_Serving(i13, j13, Serving)
Rel_Realization(i12, j12, Realization)
Rel_Influence(i11, j11, Influence)
Rel_Flow(i10, j10, Flow)
Rel_Composition(i9, j9, Composition)
Rel_Association_dir(i7, j7, \\nAssociation_dir)
Rel_Association(i7, j7, Association)
Rel_Assignment(i6, j6, Assignment)
Rel_Aggregation(i5, j5, Aggregation)
Rel_Access_w(i4, j4, Access_w)
Rel_Access_rw(i4, j4, Access_rw)
Rel_Access_r(i4, j4, Access_r)
Rel_Access(i4, j4, Access)
@enduml
''',
  ),
];
