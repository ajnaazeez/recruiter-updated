import 'package:flutter/material.dart';
import 'package:csc_picker_plus/csc_picker_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../jobs/controllers/job_controller.dart';
import '../../jobs/models/job_model.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../company/repositories/company_repository.dart';
import '../../subscription/views/subscription_screen.dart';

class CreateJobScreen extends ConsumerStatefulWidget {
  const CreateJobScreen({super.key});

  @override
  ConsumerState<CreateJobScreen> createState() => _CreateJobScreenState();
}

class _CreateJobScreenState extends ConsumerState<CreateJobScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _titleController = TextEditingController(); // roleName
  final _descriptionController = TextEditingController();
  final _responsibilitiesController = TextEditingController();
  final _requirementsController = TextEditingController();
  final _skillsController = TextEditingController();
  final _minSalaryController = TextEditingController();
  final _maxSalaryController = TextEditingController();

  String _employmentType = 'Full-Time';
  String _workMode = 'Onsite';
  String _experienceLevel = 'Fresher'; // Fresher or Experienced
  final _minYearsController = TextEditingController(text: '0');
  final _maxYearsController = TextEditingController(text: '0');
  final _vacanciesController = TextEditingController(text: '1');
  final _officeCountController = TextEditingController(text: '1');

  String? _countryValue;
  String? _stateValue;
  String? _cityValue;

  bool _isGeneratingAi = false;

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(jobControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Post a New Job')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Basic Info
              Text(
                'Job Details',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Job Role / Title',
                  hintText: 'e.g. Flutter Developer',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _employmentType,
                      decoration: const InputDecoration(labelText: 'Type'),
                      items: ['Full-Time', 'Part-Time', 'Contract']
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _employmentType = v!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _workMode,
                      decoration: const InputDecoration(labelText: 'Work Mode'),
                      items: ['Onsite', 'Hybrid', 'Remote']
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _workMode = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Text(
                'Location & Company Details',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),

              CSCPickerPlus(
                onCountryChanged: (value) {
                  setState(() {
                    _countryValue = value;
                  });
                },
                onStateChanged: (value) {
                  setState(() {
                    _stateValue = value;
                  });
                },
                onCityChanged: (value) {
                  setState(() {
                    _cityValue = value;
                  });
                },
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _officeCountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Number of Offices',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _vacanciesController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Number of Openings',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Skills & Description
              Text(
                'Requirements',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _skillsController,
                decoration: const InputDecoration(
                  labelText: 'Required Skills (comma separated)',
                  hintText: 'Flutter, Dart, Firebase',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // AI Generator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Job Description',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  TextButton.icon(
                    onPressed: _isGeneratingAi ? null : _generateDescription,
                    icon: _isGeneratingAi
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome),
                    label: const Text('AI Generate'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              TextFormField(
                controller: _descriptionController,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText: 'Enter detailed job description...',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              Text(
                'Key Responsibilities',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _responsibilitiesController,
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText: 'Enter responsibilities (one per line)...',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              Text(
                'Requirements',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _requirementsController,
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText: 'Enter requirements (one per line)...',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),

              const SizedBox(height: 24),

              // Experience
              Text('Experience', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: _experienceLevel,
                decoration: const InputDecoration(
                  labelText: 'Experience Level',
                  border: OutlineInputBorder(),
                ),
                items: ['Fresher', 'Experienced']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _experienceLevel = v!;
                    if (_experienceLevel == 'Fresher') {
                      _minYearsController.text = '0';
                      _maxYearsController.text = '0';
                    }
                  });
                },
              ),

              if (_experienceLevel == 'Experienced') ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _minYearsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Min Years',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _maxYearsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Max Years',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
              ],

              // Salary
              Text(
                'Salary (Yearly CTC)',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _minSalaryController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Min',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _maxSalaryController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Max',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              SizedBox(
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  ),
                  onPressed: isLoading ? null : _submitJob,
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Post Job'),
                ),
              ),
            ],
          ),
        ),
      ),
     ),
    );
  }

  Future<void> _generateDescription() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a Job Role first')),
      );
      return;
    }

    setState(() => _isGeneratingAi = true);

    try {
      final skills = _skillsController.text
          .split(',')
          .map((e) => e.trim())
          .toList();
      final content = await ref
          .read(jobControllerProvider.notifier)
          .generateJobDescription(_titleController.text, skills);

      if (mounted) {
        _descriptionController.text = content.description;
        _responsibilitiesController.text = content.responsibilities.join('\n');
        _requirementsController.text = content.requirements.join('\n');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingAi = false);
      }
    }
  }

  void _submitJob() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(authControllerProvider.notifier).currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User not authenticated')));
      return;
    }

    final recruiterProfile = await ref
        .read(authControllerProvider.notifier)
        .getRecruiterProfile(user.uid);
    if (recruiterProfile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recruiter profile not found')),
      );
      return;
    }

    // GATING: Check Subscription
    if (!recruiterProfile.isSubscribed) {
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
        );
      }
      return;
    }

    final company = await ref
        .read(companyRepositoryProvider)
        .fetchCompany(recruiterProfile.companyId);

    final job = JobModel(
      jobId: DateTime.now().millisecondsSinceEpoch.toString(),
      companyId: recruiterProfile.companyId,
      recruiterId: user.uid,
      roleId: 'custom',
      roleName: _titleController.text,
      designationId: 'custom',
      designationName: _titleController.text,
      experienceLevel: _experienceLevel,
      employmentType: _employmentType,
      workMode: _workMode,
      jobLocation: JobLocation(
        city: _cityValue ?? '',
        state: _stateValue ?? '',
        country: _countryValue ?? '',
      ),
      vacancies: int.tryParse(_vacanciesController.text) ?? 1,
      officeCount: int.tryParse(_officeCountController.text) ?? 0,
      experienceRequired: JobExperienceRequired(
        minYears: int.tryParse(_minYearsController.text) ?? 0,
        maxYears: int.tryParse(_maxYearsController.text) ?? 0,
      ),
      salary: JobSalary(
        min: double.tryParse(_minSalaryController.text) ?? 0,
        max: double.tryParse(_maxSalaryController.text) ?? 0,
        currency: 'INR',
        type: 'CTC',
      ),
      skillsRequired: _skillsController.text
          .split(',')
          .map((e) => e.trim())
          .toList(),
      mustHaveSkills: [],
      niceToHaveSkills: [],
      jobDescription: _descriptionController.text,
      responsibilities: _responsibilitiesController.text
          .split('\n')
          .where((e) => e.isNotEmpty)
          .toList(),
      requirements: _requirementsController.text
          .split('\n')
          .where((e) => e.isNotEmpty)
          .toList(),
      interviewProcess: [],
      status: 'active',
      visibility: 'public',
      postedAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 30)),
      companyName: company?.profile.companyName,
      companyLogoUrl: company?.profile.logoUrl,
    );

    ref
        .read(jobControllerProvider.notifier)
        .createJob(job: job, context: context);
  }
}
